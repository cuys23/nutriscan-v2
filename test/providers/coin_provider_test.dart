import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/providers/coins/coin_provider.dart';

Future<CoinProvider> freshProvider() async {
  final provider = CoinProvider();
  // The constructor's initial load is fire-and-forget; reloadCoins() re-runs
  // it and awaits, giving a deterministic settled state for the test.
  await provider.reloadCoins();
  return provider;
}

void main() {
  setUp(() {
    // v2 keeps the balance in secure storage rather than SharedPreferences,
    // so an empty mock store is what "first launch" looks like.
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('CoinProvider money path', () {
    test('grants initialCoins on first load', () async {
      final provider = await freshProvider();
      expect(provider.coinBalance, CoinProvider.initialCoins);
    });

    test('spendCoins succeeds and decrements balance when affordable', () async {
      final provider = await freshProvider();
      final spent = await provider.spendCoins(CoinProvider.coinsPerScan);
      expect(spent, isTrue);
      expect(
        provider.coinBalance,
        CoinProvider.initialCoins - CoinProvider.coinsPerScan,
      );
    });

    test(
      'spendCoins fails and leaves balance untouched when insufficient',
      () async {
        final provider = await freshProvider();
        final spent = await provider.spendCoins(provider.coinBalance + 1);
        expect(spent, isFalse);
        expect(provider.coinBalance, CoinProvider.initialCoins);
      },
    );

    test('addCoins credits a rewarded ad without touching totalCoinsSpent', () async {
      final provider = await freshProvider();
      final spentBefore = provider.totalCoinsSpent;
      await provider.addCoins(CoinProvider.coinsPerAd);
      expect(
        provider.coinBalance,
        CoinProvider.initialCoins + CoinProvider.coinsPerAd,
      );
      expect(provider.totalCoinsSpent, spentBefore);
    });

    test('canScan reflects whether balance still covers one scan', () async {
      final provider = await freshProvider();
      expect(provider.canScan(), isTrue);
      while (provider.canScan()) {
        await provider.spendCoins(CoinProvider.coinsPerScan);
      }
      expect(provider.canScan(), isFalse);
      // A drained balance must never let spendCoins through either — that is
      // the gate FoodProvider.analyzeFoodImage actually relies on, and
      // canScan() alone only guards the button in home_screen.
      expect(await provider.spendCoins(CoinProvider.coinsPerScan), isFalse);
    });
  });
}
