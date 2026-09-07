import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/customer_bloc.dart';
import '../../domain/entities/customer.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/security/session_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../sales/presentation/bloc/sale_bloc.dart';

/// Lists saved customers.
///
/// - selectionMode = true  -> opened from Checkout: tapping a customer
///   pops this page back with the selected [Customer].
/// - selectionMode = false -> opened from the menu: tapping a customer opens
///   their detail page (purchase history, debts, statement).
class CustomersPage extends StatefulWidget {
  final bool selectionMode;
  const CustomersPage({super.key, this.selectionMode = false});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyDebtors = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context, Customer customer) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (innerContext) {
        return AlertDialog(
          title: Text(l10n.t('delete_customer')),
          content:
              Text(l10n.t('delete_customer_confirm', {'name': customer.name})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(innerContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                context.read<CustomerBloc>().add(DeleteCustomer(customer.id));
                Navigator.pop(innerContext);
              },
              child: Text(l10n.delete,
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.adaptive.arrow_back, color: theme.primaryColor),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/menu'),
        ),
        title: Text(
          widget.selectionMode ? l10n.t('select_customer') : l10n.customers,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n.t('debts'),
            icon: Icon(
              _onlyDebtors ? Icons.money_off : Icons.money_off_csred_outlined,
              color: _onlyDebtors ? Colors.red : null,
            ),
            onPressed: () => setState(() => _onlyDebtors = !_onlyDebtors),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.t('search_name_phone'),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _searchController.clear,
                      ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<CustomerBloc, CustomerState>(
              builder: (context, state) {
                if (state.status == CustomerStatus.loading &&
                    state.customers.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final saleState = context.watch<SaleBloc>().state;
                final debtByCustomer = <String, double>{};
                for (final s in saleState.unpaidCreditSales) {
                  if (s.customerId == null) continue;
                  debtByCustomer[s.customerId!] =
                      (debtByCustomer[s.customerId!] ?? 0) + s.amountDue;
                }

                final customers = state.customers.where((c) {
                  if (_onlyDebtors && (debtByCustomer[c.id] ?? 0) <= 0) {
                    return false;
                  }
                  if (_searchQuery.isEmpty) return true;
                  return c.name.toLowerCase().contains(_searchQuery) ||
                      c.phone.toLowerCase().contains(_searchQuery);
                }).toList()
                  ..sort((a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                if (customers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline,
                              size: 48, color: theme.disabledColor),
                          const SizedBox(height: 12),
                          Text(
                            _onlyDebtors
                                ? l10n.t('no_outstanding_credit')
                                : l10n.t('no_customers'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.disabledColor),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final totalDebt = debtByCustomer.values
                    .fold(0.0, (s, v) => s + v);

                return ListView.separated(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 4, bottom: 100),
                  itemCount: customers.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      if (totalDebt <= 0 || widget.selectionMode) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined,
                                color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(l10n.t('total_outstanding'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            Text(Money.format(totalDebt),
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }
                    final customer = customers[index - 1];
                    return _CustomerCard(
                      customer: customer,
                      debt: debtByCustomer[customer.id] ?? 0,
                      selectionMode: widget.selectionMode,
                      onDelete: () => _confirmDelete(context, customer),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/customers/add'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: l10n.t('add_customer'),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final double debt;
  final bool selectionMode;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.debt,
    required this.selectionMode,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final overLimit = customer.creditLimit > 0 && debt > customer.creditLimit;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (selectionMode) {
          context.pop(customer);
        } else {
          context.push('/customers/detail/${customer.id}', extra: customer);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  if (customer.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(customer.phone,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color)),
                  ],
                  if (debt > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.t('outstanding_credit')}: ${Money.format(debt)}'
                      '${overLimit ? ' ⚠' : ''}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: overLimit ? Colors.red : Colors.orange[800]),
                    ),
                  ],
                ],
              ),
            ),
            if (selectionMode)
              const Icon(Icons.chevron_right, color: Colors.grey)
            else if (sessionController.isAdmin)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        color: AppTheme.primaryColor, size: 20),
                    tooltip: l10n.edit,
                    onPressed: () => context.push(
                        '/customers/edit/${customer.id}',
                        extra: customer),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: 20),
                    tooltip: l10n.delete,
                    onPressed: onDelete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
