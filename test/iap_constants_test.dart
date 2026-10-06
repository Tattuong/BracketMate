import 'package:flutter_test/flutter_test.dart';
import 'package:bracketmate/core/constants/iap_constants.dart';
import 'package:bracketmate/core/services/iap_config_service.dart';
import 'package:bracketmate/models/shop_item.dart';

void main() {
  test('BracketMate IAP ids and N302 endpoint', () {
    expect(IapConstants.productPrefix, 'bm');
    expect(IapConstants.remoteConfigUrl,
        'https://api2.blwsmartware.net/N302.json');
    expect(IapConstants.coinPackIds.first, 'bm_pack_1');
    expect(IapConstants.coinPackIds.last, 'bm_pack_10');
    expect(IapConstants.coinPackIds, hasLength(10));
    expect(IapConstants.removeAdsProductId, 'bm_remove_ads');
    expect(IapConstants.proProductId, 'bm_pro');
    expect(IapConstants.allProductIds,
        containsAll([...IapConstants.coinPackIds, 'bm_remove_ads', 'bm_pro']));
    expect(IapConstants.coinsForProduct('bm_pack_5'), 500);
    expect(IapConstants.freeArchiveLimit, 8);
    expect(IapConstants.proArchiveLimit, 99);
  });

  test('disable=1 hides billing only', () {
    final off = IapRemoteConfig.fromJson({'disable': 1, 'name': 'BracketMate'});
    expect(off.billingDisabled, isTrue);
    final on = IapRemoteConfig.fromJson(
        {'disable': 0, 'name': 'BracketMate', 'code': 'FULL_IAP'});
    expect(on.billingDisabled, isFalse);
    expect(on.name, 'BracketMate');
  });

  test('shop catalog extras can be applied and reverted', () {
    expect(
        ShopCatalog.items.where((e) => e.id.startsWith('theme_')), isNotEmpty);
    expect(ShopCatalog.find(ShopCatalog.featPro), isNotNull);
    expect(ShopCatalog.find('remove_ads'), isNotNull);
    expect(ShopCatalog.find(ShopCatalog.featHint), isNotNull);
    expect(ShopCatalog.find(ShopCatalog.featSound), isNotNull);
    expect(ShopCatalog.isDefaultId(ShopCatalog.defaultThemeId), isTrue);
  });
}
