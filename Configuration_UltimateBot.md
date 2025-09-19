# Configuration UltimateBot - Stop Loss Flottant

## Description
UltimateBot v2.00 est un Expert Advisor (EA) pour MetaTrader 5 qui intègre :
- Signaux de trading automatisés pour BTC/XAU 
- **Stop Loss Flottant (Break-Even)** : Garantit qu'aucune position ne devient perdante
- **Trailing Stop Dynamique** : Sécurise les gains progressivement
- Gestion multi-symboles (BTCUSD, XAUUSD)

## Fonctionnalités Principales

### 1. Stop Loss Flottant (Break-Even)
- **Objectif** : Éliminer le risque de perte une fois qu'un niveau de profit minimum est atteint
- **Activation** : Quand la position atteint `BreakEvenStart` points de profit
- **Calcul** :
  - **BUY** : Stop Loss déplacé à `Prix d'entrée + Spread + Buffer`
  - **SELL** : Stop Loss déplacé à `Prix d'entrée - Spread - Buffer`
- **Avantage** : Position garantie au minimum "break-even" (sans perte)

### 2. Trailing Stop Dynamique
- **Objectif** : Sécuriser les gains au fur et à mesure que le profit augmente
- **Activation** : Quand la position atteint `TrailingStart` points de profit
- **Fonctionnement** : Stop Loss suit le prix à distance de `TrailingStep` points
- **Compatibilité** : Fonctionne après le break-even pour optimiser les gains

## Paramètres de Configuration

### Trading
- `LotSize` : 0.01 (Taille de position)
- `MagicNumber` : 123456 (Identifiant unique)
- `TradingPairs` : "BTCUSD,XAUUSD" (Paires tradées)

### Stop Loss & Take Profit
- `StopLoss` : 100 points (SL initial)
- `TakeProfit` : 200 points (TP initial)

### Break-Even (Stop Loss Flottant)
- `UseBreakEven` : true (Activer/Désactiver)
- `BreakEvenStart` : 30 points (Profit minimum pour déclencher)
- `BreakEvenBuffer` : 5 points (Marge de sécurité)

### Trailing Stop
- `UseTrailingStop` : true (Activer/Désactiver)
- `TrailingStart` : 50 points (Profit minimum pour déclencher)
- `TrailingStep` : 10 points (Distance de suivi)

### Signaux
- `RSI_Period` : 14
- `RSI_Overbought` : 70
- `RSI_Oversold` : 30
- `MA_Fast` : 10
- `MA_Slow` : 20

## Logique de Fonctionnement

### Ordre de Priorité des Stop Loss
1. **Break-Even** : Appliqué en premier quand le profit atteint `BreakEvenStart`
2. **Trailing Stop** : Appliqué ensuite pour améliorer le SL si plus avantageux
3. **Préservation** : Le SL ne peut jamais empirer (toujours dans le sens du profit)

### Exemple Pratique (Position BUY)
```
Prix d'entrée : 50000
Spread : 10 points
Buffer : 5 points

1. Position ouverte à 50000
2. Profit atteint 30 points → Break-Even activé
   - SL déplacé à : 50000 + 10 + 5 = 50015
3. Profit atteint 50 points → Trailing Stop activé
   - SL suit le prix à -10 points
4. Si prix monte à 50100 → SL à 50090
5. Position sécurisée avec gain minimum garanti
```

## Installation

1. Copier `UltimateBot.mq5` dans le dossier `MQL5/Experts/` de MetaTrader 5
2. Compiler le fichier (F7)
3. Attacher l'EA au graphique des symboles désirés
4. Configurer les paramètres selon votre stratégie
5. Activer le trading automatisé

## Recommandations

- **Break-Even Start** : Réglez selon la volatilité du marché (20-50 points)
- **Trailing Start** : Doit être > Break-Even Start pour une logique cohérente
- **Buffer** : 3-10 points selon le spread moyen
- **Test** : Toujours tester en mode démo avant le live

## Sécurité

- ✅ Aucune position ne peut devenir perdante après activation du break-even
- ✅ Stop Loss ne peut jamais empirer (protection anti-régression)
- ✅ Gestion automatique des spreads et buffers
- ✅ Compatible avec le trailing stop existant

## Support

Pour toute question ou configuration personnalisée :
- Telegram : @plexiptvbe
- Compte VT Markets requis