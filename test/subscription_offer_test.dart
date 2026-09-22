import 'package:flutter_test/flutter_test.dart';
import 'package:studafy/features/parent/domain/parent_subscription_repository.dart';

void main() {
  test('checkout requires store availability and complete pricing terms', () {
    PaywallOffer offer({
      bool available = true,
      String product = 'monthly',
      String price = 'JOD 2.00',
      String currency = 'JOD',
      String period = 'month',
    }) => PaywallOffer(
      featureKey: 'example',
      storeProductId: product,
      storeAvailable: available,
      price: price,
      currencyCode: currency,
      periodLabel: period,
    );
    expect(offer().canPurchase, isTrue);
    for (final incomplete in [
      offer(available: false),
      offer(product: ''),
      offer(price: ''),
      offer(currency: ''),
      offer(period: ''),
      offer(price: ' '),
    ]) {
      expect(incomplete.canPurchase, isFalse);
    }
  });
}
