import 'package:billing_app/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../product/domain/entities/product.dart';
import '../../../sales/domain/entities/sale.dart';
import '../../../sales/domain/entities/sale_item.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';
import '../../../sales/presentation/pages/invoice_page.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/presentation/bloc/customer_bloc.dart';
import '../../domain/entities/payment_method.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/manager_approval.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/utils/cash_change.dart';
import '../../../../core/utils/money.dart';
import '../../../delivery/domain/entities/delivery.dart';
import '../../../delivery/presentation/widgets/checkout_delivery_sheet.dart';
import '../bloc/billing_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _customerNameController =
      TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _receivedController = TextEditingController();
  final TextEditingController _initialPaymentController =
      TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  double _received = 0;

  @override
  void initState() {
    super.initState();
    final state = context.read<BillingBloc>().state;
    if (state.discountValue > 0) {
      _discountController.text = formatQty(state.discountValue);
    }
    if (state.customerId == null && (state.customerName ?? '').isNotEmpty) {
      _customerNameController.text = state.customerName!;
      _customerPhoneController.text = state.customerPhone ?? '';
    }
    if (state.initialPayment > 0) {
      _initialPaymentController.text = formatQty(state.initialPayment);
    }
    _noteController.text = state.note;
  }

  @override
  void dispose() {
    _discountController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _receivedController.dispose();
    _initialPaymentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _reviewInvoice(
      BuildContext context, BillingState billingState,
      {DeliveryRequest? delivery}) async {
    final l10n = context.l10n;
    if (billingState.cartItems.isEmpty) return;

    // Big discounts are a classic till leak: anything beyond the configured
    // cap makes the cashier call the manager, who approves with their PIN
    // right on this screen.
    if (ManagerApproval.isRequired && billingState.discountAmount > 0) {
      final pct = billingState.subtotal <= 0
          ? 0.0
          : billingState.discountAmount / billingState.subtotal * 100;
      if (pct > ManagerApproval.discountLimitPercent + 0.0001) {
        final ok = await ManagerApproval.request(
          context,
          reasonKey: 'approval_reason_discount',
          reasonArgs: {'percent': pct.toStringAsFixed(0)},
        );
        if (!ok || !context.mounted) return;
      }
    }

    final isCredit = billingState.paymentMethod == PaymentMethod.credit;
    if (isCredit && billingState.customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('customer_required_for_credit')),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }

    final initialPayment =
        isCredit ? billingState.initialPayment.clamp(0, billingState.totalAmount).toDouble() : 0.0;

    // Credit-limit check: outstanding + new debt must stay within the limit.
    if (isCredit) {
      final customer = context
          .read<CustomerBloc>()
          .state
          .customers
          .where((c) => c.id == billingState.customerId)
          .firstOrNull;
      if (customer != null && customer.creditLimit > 0) {
        final outstanding = context
            .read<SaleBloc>()
            .state
            .unpaidCreditSales
            .where((s) => s.customerId == customer.id)
            .fold(0.0, (sum, s) => sum + s.amountDue);
        final newDebt = billingState.totalAmount - initialPayment;
        if (outstanding + newDebt > customer.creditLimit + 0.005) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.t('credit_limit')),
              content: Text(l10n.t('credit_limit_exceeded', {
                'name': customer.name,
                'limit': Money.format(customer.creditLimit)
              })),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.cancel)),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l10n.t('continue_'))),
              ],
            ),
          );
          if (proceed != true || !context.mounted) return;
        }
      }
    }

    final now = DateTime.now();
    final payments = <SalePayment>[];
    if (!isCredit) {
      payments.add(SalePayment(amount: billingState.totalAmount, dateTime: now));
    } else if (initialPayment > 0) {
      payments.add(SalePayment(
          amount: initialPayment, dateTime: now, note: l10n.t('initial_payment')));
    }

    final sale = Sale(
      id: const Uuid().v4(),
      dateTime: now,
      items: billingState.cartItems
          .map((c) => SaleItem(
                productId: c.product.id,
                productName: c.product.name,
                unitPrice: c.unitPrice,
                unitCost: c.product.costPrice,
                quantity: c.quantity,
                unit: c.product.unit,
              ))
          .toList(),
      subtotal: billingState.subtotal,
      discountAmount: billingState.discountAmount,
      promoDiscount: billingState.promoDiscount,
      promoDescription:
          billingState.appliedPromos.map((p) => p.label).join(' · '),
      total: billingState.totalAmount,
      paymentMethod: billingState.paymentMethod,
      isPaid: !isCredit || initialPayment + 0.005 >= billingState.totalAmount,
      customerId: billingState.customerId,
      customerName: (billingState.customerName ?? '').trim().isNotEmpty
          ? billingState.customerName!.trim()
          : null,
      customerPhone: (billingState.customerPhone ?? '').trim().isNotEmpty
          ? billingState.customerPhone!.trim()
          : null,
      payments: payments,
      cashierId: sessionController.cashierId,
      cashierName: sessionController.cashierName,
      note: billingState.note.trim().isEmpty ? null : billingState.note.trim(),
    );

    await context.push('/invoice',
        extra:
            InvoiceRouteArgs(sale: sale, isDraft: true, delivery: delivery));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const borderColor = Color(0xFFE5E5EA);

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          // Keep the cart: the cashier may just want to add one more item.
          context.go('/');
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.t('checkout'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.adaptive.arrow_back,
                  color: Theme.of(context).primaryColor),
              onPressed: () => context.go('/'),
            ),
            actions: [
              IconButton(
                tooltip: l10n.t('clear_cart'),
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () {
                  context.read<BillingBloc>().add(ClearCartEvent());
                  context.go('/');
                },
              ),
            ],
          ),
          body: BlocBuilder<BillingBloc, BillingState>(
            builder: (context, billingState) {
              final isCredit =
                  billingState.paymentMethod == PaymentMethod.credit;
              final change = _received - billingState.totalAmount;
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Column(
                        children: [
                          _buildItemsTable(context, billingState, borderColor),
                          const SizedBox(height: 16),
                          _buildDiscountSection(context, billingState),
                          if (billingState.appliedPromos.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildOffersSection(context, billingState),
                          ],
                          const SizedBox(height: 16),
                          _buildPaymentMethodSection(context, billingState),
                          const SizedBox(height: 16),
                          _buildCustomerSection(context, billingState),
                          const SizedBox(height: 16),
                          if (!isCredit)
                            _buildCashSection(context, billingState, change)
                          else
                            _buildInitialPaymentSection(context, billingState),
                          const SizedBox(height: 16),
                          _buildNoteSection(context),
                          const SizedBox(height: 16),
                          _buildMarginGuard(context, billingState),
                          const SizedBox(height: 104),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomBar(context, billingState),
                ],
              );
            },
          ),
        ));
  }

  Widget _buildItemsTable(
      BuildContext context, BillingState billingState, Color borderColor) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppTheme.brMd,
        border: Border.all(color: borderColor),
        boxShadow: AppTheme.shadow(Theme.of(context).brightness),
      ),
      child: ClipRRect(
        borderRadius: AppTheme.brMd,
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1.6),
            2: FlexColumnWidth(1.6),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: context.surfaceAltColor,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              children: [
                _buildHeaderCell(context, l10n.t('product_name'), TextAlign.start),
                _buildHeaderCell(context, l10n.price, TextAlign.end),
                _buildHeaderCell(context, l10n.total, TextAlign.end),
              ],
            ),
            ...billingState.cartItems.map((item) {
              final unit = l10n.t(item.product.unit.shortKey);
              return TableRow(
                children: [
                  _buildDataCell(
                    context,
                    '${formatQty(item.quantity)} $unit × ${item.product.name}',
                    TextAlign.start,
                  ),
                  _buildDataCell(
                      context, Money.format(item.unitPrice), TextAlign.end,
                      isSubtitle: true),
                  _buildDataCell(
                      context, Money.format(item.total), TextAlign.end,
                      isBold: true),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, BillingState billingState) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: context.borderColor)),
        boxShadow: AppTheme.shadow(Theme.of(context).brightness, strong: true),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                children: [
                  if (billingState.discountAmount > 0 ||
                      billingState.promoDiscount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.subtotal,
                            style: TextStyle(
                                fontSize: 12, color: context.mutedColor)),
                        Text(Money.format(billingState.subtotal),
                            style: TextStyle(
                                fontSize: 12, color: context.mutedColor)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (billingState.discountAmount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${l10n.discount}${billingState.discountIsPercent ? ' (${formatQty(billingState.discountValue)}%)' : ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.warning)),
                          Text('-${Money.format(billingState.discountAmount)}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.warning)),
                        ],
                      ),
                    if (billingState.promoDiscount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_offer_outlined,
                                    size: 13, color: AppTheme.success),
                                const SizedBox(width: 4),
                                Text(l10n.t('offers_discount'),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.success)),
                              ],
                            ),
                            Text(
                                '-${Money.format(billingState.promoDiscount)}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.success)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.grandTotal.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.mutedColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        Money.format(billingState.totalAmount),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    onPressed: () => _reviewInvoice(context, billingState),
                    label: l10n.t('review_invoice'),
                    icon: Icons.receipt_long,
                    isLoading: false,
                  ),
                ),
                const SizedBox(width: 10),
                _buildDeliveryButton(context, billingState),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Truck button beside "review invoice": collects the delivery details
  /// and continues straight into the normal invoice flow — the order is
  /// written to the database when the sale is stored.
  Widget _buildDeliveryButton(BuildContext context, BillingState state) {
    final enabled = state.cartItems.isNotEmpty;
    return Material(
      color: enabled
          ? Theme.of(context).colorScheme.tertiaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: AppTheme.brMd,
      child: InkWell(
        borderRadius: AppTheme.brMd,
        onTap: !enabled
            ? null
            : () async {
                final request = await showDeliverySheet(context);
                if (request != null && context.mounted) {
                  await _reviewInvoice(context, state, delivery: request);
                }
              },
        child: SizedBox(
          height: 52,
          width: 56,
          child: Icon(
            Icons.delivery_dining_rounded,
            size: 26,
            color: enabled
                ? Theme.of(context).colorScheme.onTertiaryContainer
                : context.mutedColor,
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppTheme.brMd,
        border: Border.all(color: context.borderColor),
        boxShadow: AppTheme.shadow(Theme.of(context).brightness),
      );

  Widget _buildDiscountSection(BuildContext context, BillingState state) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('discount_optional'),
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '0'),
                  onChanged: (value) {
                    context.read<BillingBloc>().add(SetDiscountEvent(
                        value: parseAmount(value),
                        isPercent: state.discountIsPercent));
                  },
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(Money.symbol)),
                  const ButtonSegment(value: true, label: Text('%')),
                ],
                selected: {state.discountIsPercent},
                onSelectionChanged: (selection) {
                  context.read<BillingBloc>().add(SetDiscountEvent(
                      value: state.discountValue,
                      isPercent: selection.first));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Which offers fired on this bill, so the cashier can answer "why is it
  /// cheaper?" without guessing.
  Widget _buildOffersSection(BuildContext context, BillingState state) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context).copyWith(
        border:
            Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
        color: AppTheme.success.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_rounded,
                  size: 16, color: AppTheme.success),
              const SizedBox(width: 6),
              Text(l10n.t('offers_applied'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.success)),
            ],
          ),
          const SizedBox(height: 8),
          for (final promo in state.appliedPromos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(promo.label,
                          style: const TextStyle(fontSize: 12))),
                  Text('-${Money.format(promo.amount)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(BuildContext context, BillingState state) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('payment_method'),
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PaymentMethod.values.map((method) {
              final selected = state.paymentMethod == method;
              return ChoiceChip(
                avatar: Icon(
                    method == PaymentMethod.cash
                        ? Icons.payments_outlined
                        : Icons.schedule,
                    size: 18,
                    color: selected ? AppTheme.primaryColor : Colors.grey),
                label: Text(l10n.t(method.labelKey)),
                selected: selected,
                onSelected: (_) => context
                    .read<BillingBloc>()
                    .add(SetPaymentMethodEvent(method)),
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                    color: selected
                        ? AppTheme.primaryColor
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCashSection(
      BuildContext context, BillingState state, double change) {
    final l10n = context.l10n;
    final quick = _quickAmounts(state.totalAmount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('amount_received'),
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          TextField(
            controller: _receivedController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                hintText: Money.plain(state.totalAmount),
                prefixText: '${Money.symbol} '),
            onChanged: (v) => setState(() => _received = parseAmount(v)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: quick
                .map((a) => ActionChip(
                      label: Text(Money.format(a)),
                      onPressed: () => setState(() {
                        _received = a;
                        _receivedController.text = formatQty(a);
                      }),
                    ))
                .toList(),
          ),
          if (_received > 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.t('change_due'),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  Money.format(change < 0 ? 0 : change),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: change < 0 ? AppTheme.danger : AppTheme.success),
                ),
              ],
            ),
            if (change > 0) _buildChangeBreakdown(context, change),
          ],
        ],
      ),
    );
  }

  List<double> _quickAmounts(double total) {
    final result = <double>{};
    final exact = total;
    result.add(exact);
    for (final step in [100, 200, 500, 1000, 2000]) {
      final rounded = ((total / step).ceil() * step).toDouble();
      if (rounded > total) result.add(rounded);
      if (result.length >= 4) break;
    }
    return result.toList()..sort();
  }

  Widget _buildInitialPaymentSection(BuildContext context, BillingState state) {
    final l10n = context.l10n;
    final remaining = state.totalAmount - state.initialPayment;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.t('initial_payment'),
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(l10n.t('initial_payment_hint'),
              style: TextStyle(fontSize: 11, color: context.mutedColor)),
          const SizedBox(height: 10),
          TextField(
            controller: _initialPaymentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: '${Money.symbol} ',
              errorText: state.initialPayment > state.totalAmount + 0.005
                  ? l10n.t('payment_exceeds',
                      {'amount': Money.format(state.totalAmount)})
                  : null,
            ),
            onChanged: (v) => context
                .read<BillingBloc>()
                .add(SetInitialPaymentEvent(parseAmount(v))),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.t('remaining'),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(Money.format(remaining < 0 ? 0 : remaining),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.warning)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: TextField(
        controller: _noteController,
        maxLines: 2,
        minLines: 1,
        decoration: InputDecoration(
          hintText: l10n.t('sale_note'),
          prefixIcon: const Icon(Icons.sticky_note_2_outlined),
        ),
        onChanged: (v) => context.read<BillingBloc>().add(SetSaleNoteEvent(v)),
      ),
    );
  }

  Widget _buildCustomerSection(BuildContext context, BillingState state) {
    final l10n = context.l10n;
    final hasSavedCustomer = state.customerId != null;
    final isCredit = state.paymentMethod == PaymentMethod.credit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context).copyWith(
        border: Border.all(
            color: isCredit && !hasSavedCustomer
                ? AppTheme.warning
                : context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                    isCredit ? l10n.customer : l10n.t('customer_optional'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              TextButton.icon(
                onPressed: () async {
                  final selected =
                      await context.push<Customer>('/customers/picker');
                  if (selected != null && context.mounted) {
                    context
                        .read<BillingBloc>()
                        .add(SelectCustomerEvent(selected));
                  }
                },
                icon: const Icon(Icons.people_outline, size: 18),
                label: Text(l10n.t('select_saved')),
              ),
            ],
          ),
          if (isCredit && !hasSavedCustomer)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l10n.t('customer_required_for_credit'),
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.warning)),
            ),
          const SizedBox(height: 4),
          if (hasSavedCustomer)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                        '${state.customerName ?? ''}'
                        '${(state.customerPhone ?? '').isNotEmpty ? ' · ${state.customerPhone}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      context.read<BillingBloc>().add(ClearCustomerEvent()),
                ),
              ],
            )
          else ...[
            TextField(
              controller: _customerNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(hintText: l10n.t('name_walk_in')),
              onChanged: (value) => context.read<BillingBloc>().add(
                  SetCustomerInfoEvent(
                      name: value, phone: _customerPhoneController.text)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(hintText: l10n.phone),
              onChanged: (value) => context.read<BillingBloc>().add(
                  SetCustomerInfoEvent(
                      name: _customerNameController.text, phone: value)),
            ),
          ],
        ],
      ),
    );
  }

  /// Exactly which notes and coins to hand back — no mental arithmetic
  /// during a rush.
  Widget _buildChangeBreakdown(BuildContext context, double change) {
    final l10n = context.l10n;
    final parts = CashChange.breakdown(change);
    if (parts.isEmpty) return const SizedBox.shrink();
    final leftover = CashChange.remainder(change);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_outlined,
                  size: 15, color: context.mutedColor),
              const SizedBox(width: 6),
              Text(l10n.t('change_breakdown'),
                  style: TextStyle(fontSize: 12, color: context.mutedColor)),
              const Spacer(),
              Text(
                  l10n.t('change_pieces',
                      {'count': CashChange.pieceCount(parts)}),
                  style: TextStyle(fontSize: 11, color: context.mutedColor)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final part in parts)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    '${part.count} × ${Money.format(part.value.toDouble())}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success),
                  ),
                ),
            ],
          ),
          if (leftover > 0) ...[
            const SizedBox(height: 6),
            Text(
              l10n.t('change_remainder', {'amount': Money.format(leftover)}),
              style: const TextStyle(fontSize: 11, color: AppTheme.warning),
            ),
          ],
        ],
      ),
    );
  }

  /// Live margin guard: shows the profit this invoice will make and shouts
  /// when a discount (or an edited price) pushes it under the cost price.
  Widget _buildMarginGuard(BuildContext context, BillingState state) {
    if (!sessionController.isAdmin || state.cartItems.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    double cost = 0;
    bool missingCost = false;
    for (final item in state.cartItems) {
      if (item.product.costPrice <= 0) {
        missingCost = true;
      } else {
        cost += item.product.costPrice * item.quantity;
      }
    }
    if (cost <= 0) return const SizedBox.shrink();

    final profit = state.totalAmount - cost;
    final margin = state.totalAmount <= 0 ? 0.0 : (profit / state.totalAmount) * 100;
    final atLoss = profit < -0.005;
    final color = atLoss
        ? AppTheme.danger
        : (margin < 5 ? AppTheme.warning : AppTheme.success);
    // Silent when the discount is negligible and the margin is healthy.
    if (!atLoss && margin >= 5 && state.discountAmount <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: AppTheme.brMd,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(atLoss ? Icons.trending_down_rounded : Icons.insights_rounded,
                color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    atLoss
                        ? l10n.t('selling_at_loss',
                            {'amount': Money.format(profit.abs())})
                        : '${l10n.t('expected_profit')}: ${Money.format(profit)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      l10n.t('margin_percent',
                          {'percent': margin.toStringAsFixed(1)}),
                      if (missingCost) l10n.t('cost_unknown'),
                    ].join(' · '),
                    style:
                        TextStyle(fontSize: 11, color: context.mutedColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: context.mutedColor,
        ),
      ),
    );
  }

  Widget _buildDataCell(BuildContext context, String text, TextAlign align,
      {bool isBold = false, bool isSubtitle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isSubtitle ? 12 : 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: isSubtitle ? context.mutedColor : null,
        ),
      ),
    );
  }
}
