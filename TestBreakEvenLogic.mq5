//+------------------------------------------------------------------+
//|                                            TestBreakEvenLogic.mq5 |
//|                        Test Script pour la logique Break-Even    |
//+------------------------------------------------------------------+
#property copyright "Test Break-Even Logic"
#property version   "1.00"
#property script_show_inputs

// Paramètres de test
input double OpenPrice = 50000.0;       // Prix d'entrée
input double CurrentPrice = 50035.0;    // Prix actuel
input double Spread = 10.0;             // Spread en points
input int BreakEvenStart = 30;          // Seuil break-even
input int BreakEvenBuffer = 5;          // Buffer sécurité
input double Point = 0.1;               // Valeur d'un point

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== TEST LOGIQUE BREAK-EVEN ULTIMATEBOT ===");
    
    // Test position BUY
    TestBreakEvenBuy();
    
    // Test position SELL  
    TestBreakEvenSell();
    
    Print("=== FIN DES TESTS ===");
}

//+------------------------------------------------------------------+
//| Test Break-Even pour position BUY                               |
//+------------------------------------------------------------------+
void TestBreakEvenBuy()
{
    Print("\n--- TEST POSITION BUY ---");
    Print("Prix d'entrée: ", OpenPrice);
    Print("Prix actuel: ", CurrentPrice);
    Print("Spread: ", Spread, " points");
    
    double profitPoints = (CurrentPrice - OpenPrice) / Point;
    Print("Profit actuel: ", profitPoints, " points");
    
    if(profitPoints >= BreakEvenStart)
    {
        double breakEvenPrice = OpenPrice + (Spread * Point) + (BreakEvenBuffer * Point);
        Print("✅ Break-Even ACTIVÉ");
        Print("Stop Loss déplacé à: ", breakEvenPrice);
        Print("Protection: ", breakEvenPrice - OpenPrice, " points au-dessus de l'entrée");
        
        // Vérification sécurité
        if(breakEvenPrice > OpenPrice)
        {
            Print("✅ Sécurité OK: Position garantie sans perte");
        }
        else
        {
            Print("❌ ERREUR: Break-even en dessous du prix d'entrée!");
        }
    }
    else
    {
        Print("⏳ Break-Even pas encore activé (besoin de ", BreakEvenStart, " points)");
    }
}

//+------------------------------------------------------------------+
//| Test Break-Even pour position SELL                              |
//+------------------------------------------------------------------+
void TestBreakEvenSell()
{
    Print("\n--- TEST POSITION SELL ---");
    double sellOpenPrice = 50000.0;
    double sellCurrentPrice = 49965.0;  // Prix baissé = profit pour SELL
    
    Print("Prix d'entrée: ", sellOpenPrice);
    Print("Prix actuel: ", sellCurrentPrice);
    Print("Spread: ", Spread, " points");
    
    double profitPoints = (sellOpenPrice - sellCurrentPrice) / Point;
    Print("Profit actuel: ", profitPoints, " points");
    
    if(profitPoints >= BreakEvenStart)
    {
        double breakEvenPrice = sellOpenPrice - (Spread * Point) - (BreakEvenBuffer * Point);
        Print("✅ Break-Even ACTIVÉ");
        Print("Stop Loss déplacé à: ", breakEvenPrice);
        Print("Protection: ", sellOpenPrice - breakEvenPrice, " points en dessous de l'entrée");
        
        // Vérification sécurité
        if(breakEvenPrice < sellOpenPrice)
        {
            Print("✅ Sécurité OK: Position garantie sans perte");
        }
        else
        {
            Print("❌ ERREUR: Break-even au-dessus du prix d'entrée!");
        }
    }
    else
    {
        Print("⏳ Break-Even pas encore activé (besoin de ", BreakEvenStart, " points)");
    }
}