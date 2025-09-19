//+------------------------------------------------------------------+
//|                                                   UltimateBot.mq5 |
//|                        Copyright 2023, VT Markets Trading Bot   |
//|                                             https://vtmarkets.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, VT Markets Trading Bot"
#property link      "https://vtmarkets.com"
#property version   "2.00"
#property description "Bot de trading amélioré pour BTC/XAU avec stop loss flottant (break-even)"

#include <Trade\Trade.mqh>

//--- Input parameters
input group "=== Paramètres de Trading ==="
input double LotSize = 0.01;                    // Taille de lot
input int MagicNumber = 123456;                 // Numéro magique
input string TradingPairs = "BTCUSD,XAUUSD";   // Paires à trader (séparées par virgule)

input group "=== Stop Loss et Take Profit ==="
input int StopLoss = 100;                       // Stop Loss en points
input int TakeProfit = 200;                     // Take Profit en points

input group "=== Trailing Stop Dynamique ==="
input bool UseTrailingStop = true;             // Activer le trailing stop
input int TrailingStart = 50;                   // Démarrer trailing après X points de profit
input int TrailingStep = 10;                    // Pas du trailing stop en points

input group "=== Stop Loss Flottant (Break-Even) ==="
input bool UseBreakEven = true;                // Activer le break-even
input int BreakEvenStart = 30;                  // Démarrer break-even après X points de profit
input int BreakEvenBuffer = 5;                  // Buffer de sécurité en points

input group "=== Signaux de Trading ==="
input int RSI_Period = 14;                     // Période RSI
input int RSI_Overbought = 70;                 // RSI suracheté
input int RSI_Oversold = 30;                   // RSI survendu
input int MA_Fast = 10;                        // MA rapide
input int MA_Slow = 20;                        // MA lente

//--- Global variables
CTrade trade;
string symbols[];
int symbolsCount;
datetime lastBarTime[];

// Handles pour les indicateurs
int handleRSI[];
int handleMA_Fast[];
int handleMA_Slow[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Configuration du trade
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_IOC);
    
    // Parse trading pairs
    ParseTradingPairs();
    
    // Initialize arrays
    ArrayResize(lastBarTime, symbolsCount);
    ArrayResize(handleRSI, symbolsCount);
    ArrayResize(handleMA_Fast, symbolsCount);
    ArrayResize(handleMA_Slow, symbolsCount);
    
    // Initialize indicators for each symbol
    for(int i = 0; i < symbolsCount; i++)
    {
        lastBarTime[i] = 0;
        
        // Create RSI handle
        handleRSI[i] = iRSI(symbols[i], PERIOD_M15, RSI_Period, PRICE_CLOSE);
        if(handleRSI[i] == INVALID_HANDLE)
        {
            Print("Erreur création handle RSI pour ", symbols[i]);
            return INIT_FAILED;
        }
        
        // Create MA handles
        handleMA_Fast[i] = iMA(symbols[i], PERIOD_M15, MA_Fast, 0, MODE_SMA, PRICE_CLOSE);
        handleMA_Slow[i] = iMA(symbols[i], PERIOD_M15, MA_Slow, 0, MODE_SMA, PRICE_CLOSE);
        
        if(handleMA_Fast[i] == INVALID_HANDLE || handleMA_Slow[i] == INVALID_HANDLE)
        {
            Print("Erreur création handle MA pour ", symbols[i]);
            return INIT_FAILED;
        }
    }
    
    Print("UltimateBot initialisé avec succès pour ", symbolsCount, " symboles");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    for(int i = 0; i < symbolsCount; i++)
    {
        if(handleRSI[i] != INVALID_HANDLE)
            IndicatorRelease(handleRSI[i]);
        if(handleMA_Fast[i] != INVALID_HANDLE)
            IndicatorRelease(handleMA_Fast[i]);
        if(handleMA_Slow[i] != INVALID_HANDLE)
            IndicatorRelease(handleMA_Slow[i]);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Gestion des positions existantes (trailing stop + break-even)
    ManageOpenPositions();
    
    // Vérification des signaux de trading pour chaque symbole
    for(int i = 0; i < symbolsCount; i++)
    {
        string symbol = symbols[i];
        
        // Check for new bar
        datetime currentBarTime = iTime(symbol, PERIOD_M15, 0);
        if(currentBarTime != lastBarTime[i])
        {
            lastBarTime[i] = currentBarTime;
            
            // Check trading signals
            CheckTradingSignals(symbol, i);
        }
    }
}

//+------------------------------------------------------------------+
//| Gestion des positions ouvertes (Trailing Stop + Break-Even)     |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByIndex(i))
        {
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
                continue;
                
            string symbol = PositionGetString(POSITION_SYMBOL);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                                 SymbolInfoDouble(symbol, SYMBOL_BID) : 
                                 SymbolInfoDouble(symbol, SYMBOL_ASK);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            double spread = SymbolInfoDouble(symbol, SYMBOL_SPREAD) * point;
            
            bool slModified = false;
            double newSL = currentSL;
            
            // ***** STOP LOSS FLOTTANT (BREAK-EVEN) *****
            if(UseBreakEven)
            {
                slModified = ApplyBreakEven(symbol, posType, openPrice, currentPrice, currentSL, 
                                          point, spread, newSL) || slModified;
            }
            
            // ***** TRAILING STOP DYNAMIQUE *****
            if(UseTrailingStop)
            {
                slModified = ApplyTrailingStop(symbol, posType, openPrice, currentPrice, currentSL, 
                                             point, newSL) || slModified;
            }
            
            // Modifier le stop loss si nécessaire
            if(slModified && newSL != currentSL)
            {
                if(trade.PositionModify(ticket, newSL, currentTP))
                {
                    Print("Stop Loss modifié pour ", symbol, " - Nouveau SL: ", newSL);
                }
                else
                {
                    Print("Erreur modification SL pour ", symbol, " - Code: ", GetLastError());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Application du Stop Loss Flottant (Break-Even)                  |
//+------------------------------------------------------------------+
bool ApplyBreakEven(string symbol, ENUM_POSITION_TYPE posType, double openPrice, 
                   double currentPrice, double currentSL, double point, double spread, 
                   double &newSL)
{
    double profitPoints;
    double breakEvenPrice;
    bool canApplyBreakEven = false;
    
    if(posType == POSITION_TYPE_BUY)
    {
        profitPoints = (currentPrice - openPrice) / point;
        breakEvenPrice = openPrice + spread + (BreakEvenBuffer * point);
        
        // Vérifier si on peut appliquer le break-even
        if(profitPoints >= BreakEvenStart && 
           (currentSL == 0 || currentSL < breakEvenPrice))
        {
            // S'assurer que le nouveau SL est supérieur à l'actuel
            if(currentSL == 0 || breakEvenPrice > currentSL)
            {
                newSL = breakEvenPrice;
                canApplyBreakEven = true;
            }
        }
    }
    else // POSITION_TYPE_SELL
    {
        profitPoints = (openPrice - currentPrice) / point;
        breakEvenPrice = openPrice - spread - (BreakEvenBuffer * point);
        
        // Vérifier si on peut appliquer le break-even
        if(profitPoints >= BreakEvenStart && 
           (currentSL == 0 || currentSL > breakEvenPrice))
        {
            // S'assurer que le nouveau SL est inférieur à l'actuel (pour SELL)
            if(currentSL == 0 || breakEvenPrice < currentSL)
            {
                newSL = breakEvenPrice;
                canApplyBreakEven = true;
            }
        }
    }
    
    if(canApplyBreakEven)
    {
        Print("Break-Even appliqué pour ", symbol, " - Profit: ", profitPoints, " points");
    }
    
    return canApplyBreakEven;
}

//+------------------------------------------------------------------+
//| Application du Trailing Stop Dynamique                          |
//+------------------------------------------------------------------+
bool ApplyTrailingStop(string symbol, ENUM_POSITION_TYPE posType, double openPrice, 
                      double currentPrice, double currentSL, double point, double &newSL)
{
    double profitPoints;
    double newTrailingSL;
    bool canApplyTrailing = false;
    
    if(posType == POSITION_TYPE_BUY)
    {
        profitPoints = (currentPrice - openPrice) / point;
        
        if(profitPoints >= TrailingStart)
        {
            newTrailingSL = currentPrice - (TrailingStep * point);
            
            // Appliquer seulement si le nouveau SL est meilleur que l'actuel
            if(currentSL == 0 || newTrailingSL > currentSL)
            {
                // Vérifier si on doit garder le break-even ou utiliser le trailing
                if(newSL == currentSL || newTrailingSL > newSL)
                {
                    newSL = newTrailingSL;
                    canApplyTrailing = true;
                }
            }
        }
    }
    else // POSITION_TYPE_SELL
    {
        profitPoints = (openPrice - currentPrice) / point;
        
        if(profitPoints >= TrailingStart)
        {
            newTrailingSL = currentPrice + (TrailingStep * point);
            
            // Appliquer seulement si le nouveau SL est meilleur que l'actuel
            if(currentSL == 0 || newTrailingSL < currentSL)
            {
                // Vérifier si on doit garder le break-even ou utiliser le trailing
                if(newSL == currentSL || newTrailingSL < newSL)
                {
                    newSL = newTrailingSL;
                    canApplyTrailing = true;
                }
            }
        }
    }
    
    return canApplyTrailing;
}

//+------------------------------------------------------------------+
//| Vérification des signaux de trading                             |
//+------------------------------------------------------------------+
void CheckTradingSignals(string symbol, int index)
{
    // Vérifier s'il y a déjà une position sur ce symbole
    if(PositionSelect(symbol))
        return;
    
    // Get indicator values
    double rsiValues[2];
    double maFastValues[2];
    double maSlowValues[2];
    
    if(CopyBuffer(handleRSI[index], 0, 0, 2, rsiValues) != 2 ||
       CopyBuffer(handleMA_Fast[index], 0, 0, 2, maFastValues) != 2 ||
       CopyBuffer(handleMA_Slow[index], 0, 0, 2, maSlowValues) != 2)
    {
        Print("Erreur lecture indicateurs pour ", symbol);
        return;
    }
    
    // Signal d'achat
    if(rsiValues[0] < RSI_Oversold && rsiValues[1] >= RSI_Oversold &&
       maFastValues[0] > maSlowValues[0] && maFastValues[1] <= maSlowValues[1])
    {
        OpenPosition(symbol, ORDER_TYPE_BUY);
    }
    // Signal de vente
    else if(rsiValues[0] > RSI_Overbought && rsiValues[1] <= RSI_Overbought &&
            maFastValues[0] < maSlowValues[0] && maFastValues[1] >= maSlowValues[1])
    {
        OpenPosition(symbol, ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| Ouverture d'une position                                        |
//+------------------------------------------------------------------+
void OpenPosition(string symbol, ENUM_ORDER_TYPE orderType)
{
    double price = (orderType == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(symbol, SYMBOL_BID);
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double sl = 0, tp = 0;
    
    // Calculer SL et TP
    if(StopLoss > 0)
    {
        sl = (orderType == ORDER_TYPE_BUY) ? 
             price - StopLoss * point : 
             price + StopLoss * point;
    }
    
    if(TakeProfit > 0)
    {
        tp = (orderType == ORDER_TYPE_BUY) ? 
             price + TakeProfit * point : 
             price - TakeProfit * point;
    }
    
    // Ouvrir la position
    if(trade.PositionOpen(symbol, orderType, LotSize, price, sl, tp, "UltimateBot"))
    {
        Print("Position ouverte: ", symbol, " ", EnumToString(orderType), " à ", price);
    }
    else
    {
        Print("Erreur ouverture position ", symbol, " - Code: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Parse trading pairs from input string                           |
//+------------------------------------------------------------------+
void ParseTradingPairs()
{
    string temp = TradingPairs;
    string delimiter = ",";
    
    // Count symbols
    symbolsCount = 1;
    for(int i = 0; i < StringLen(temp); i++)
    {
        if(StringSubstr(temp, i, 1) == delimiter)
            symbolsCount++;
    }
    
    // Resize array
    ArrayResize(symbols, symbolsCount);
    
    // Extract symbols
    int pos = 0;
    for(int i = 0; i < symbolsCount; i++)
    {
        int nextPos = StringFind(temp, delimiter, pos);
        if(nextPos == -1)
            nextPos = StringLen(temp);
            
        symbols[i] = StringSubstr(temp, pos, nextPos - pos);
        StringTrimLeft(symbols[i]);
        StringTrimRight(symbols[i]);
        
        pos = nextPos + 1;
    }
}