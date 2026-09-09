import 'package:fpdart/fpdart.dart';
import '../../../../core/cloud/cloud_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/shop_repository.dart';

class ShopRepositoryImpl implements ShopRepository {
  static const String shopKey = 'shop_details';

  /// Used before the merchant fills in their details.
  /// Empty name/footer so the UI falls back to localized defaults
  /// (app title / "thank you") instead of English text.
  static const Shop defaultShop = Shop();

  @override
  Future<Either<Failure, Shop>> getShop() async {
    try {
      final shop = CloudDatabase.shopBox.get(shopKey);
      return Right(shop ?? defaultShop);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateShop(Shop shop) async {
    try {
      await CloudDatabase.shopBox.put(shopKey, shop);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  /// Synchronous accessor for places that can't await (PDF/receipt builders).
  static Shop current() => CloudDatabase.shopBox.get(shopKey) ?? defaultShop;
}
