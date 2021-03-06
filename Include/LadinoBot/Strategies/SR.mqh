//+------------------------------------------------------------------+
//|                                                           SR.mqh |
//|                                                   Rodrigo Landim |
//|                                        http://www.emagine.com.br |
//+------------------------------------------------------------------+
#property copyright "Rodrigo Landim"
#property link      "http://www.emagine.com.br"
#property version   "1.00"

#include <LadinoBot/Utils.mqh>

class SR {
   private:
      ENUM_TIMEFRAMES _periodo;
      int MAX_CANDLE;
      int FractalHandle;
      ENUM_SINAL_TENDENCIA tendenciaSR;
      double maximaDia;
      double minimaDia;
      double SellBuffer[];
      double BuyBuffer[];
   public:
      SR();
      ~SR();
      bool inicializar(ENUM_TIMEFRAMES periodo = PERIOD_CURRENT);
      bool atualizar(DADOS_SR& dados[]);
      double minimaDoDia();
      double maximaDoDia();
      ENUM_SINAL_TENDENCIA tendenciaAtual(DADOS_SR& dados[], double preco);
      double suporteAtual(DADOS_SR& dados[]);
      double resistenciaAtual(DADOS_SR& dados[]);
      virtual void escreverLog(string msg);
};
//+------------------------------------------------------------------+
SR::SR() {
   tendenciaSR = INDEFINIDA;
   maximaDia = 0;
   minimaDia = 0;
   MAX_CANDLE = 100;
}

SR::~SR() {
}

bool SR::inicializar(ENUM_TIMEFRAMES periodo = PERIOD_CURRENT) {

   _periodo = periodo;

   FractalHandle = iFractals(_Symbol, _periodo);
   if(FractalHandle == INVALID_HANDLE) {
      Print("Erro ao criar indicador fractal.");
      return false;
   }
   return true;
}

bool SR::atualizar(DADOS_SR& dados[]) {

   const int inicio = 1;

   double resistencia[], suporte[];
   
   ArrayResize(resistencia, MAX_CANDLE);
   ArrayResize(suporte, MAX_CANDLE);
   ArrayFree(resistencia);
   ArrayFree(suporte);
   
   if (CopyBuffer(FractalHandle, 0, inicio, MAX_CANDLE, resistencia) <= 0) {
      Print("Erro ao criar indicador de suporte e resistência.");
      return false;
   }
   if (CopyBuffer(FractalHandle, 1, inicio, MAX_CANDLE, suporte) <= 0) {
      Print("Erro ao criar indicador de suporte e resistência.");
      return false;
   }
 
   MqlRates rt[];
   ArrayResize(rt, MAX_CANDLE);
   if(CopyRates(_Symbol, _periodo, inicio, MAX_CANDLE, rt) != MAX_CANDLE) {
      Print("CopyRates of ",_periodo," failed, no history");
      return false;
   }
   
   DADOS_SR dados2[];
   ArrayFree(dados2);
   int a = 0;
   double s = suporte[0];
   double r = resistencia[0];
   for (int i = 0; i < MAX_CANDLE; i++) {
      if (resistencia[i] != EMPTY_VALUE && resistencia[i] != r) {
         r = resistencia[i];
         if (resistencia[i] > 0) {
            ArrayResize(dados2, ArraySize(dados2) + 1);
            dados2[a].index = i;
            dados2[a].data = rt[i].time;
            dados2[a].posicao = NormalizeDouble(r, _Digits);
            dados2[a].tipo = TIPO_RESISTENCIA;
            a++;
         }         
      }
      if (suporte[i] != EMPTY_VALUE && suporte[i] != s) {
         s = suporte[i];
         if (suporte[i] > 0) {
            ArrayResize(dados2, ArraySize(dados2) + 1);
            dados2[a].index = i;
            dados2[a].data = rt[i].time;
            dados2[a].posicao = NormalizeDouble(s, _Digits);
            dados2[a].tipo = TIPO_SUPORTE;
            a++;
         }
      }
   }
   
   if (ArraySize(dados2) > 0) {
      a = -1;
      ArrayFree(dados);
      for (int i = 0; i < ArraySize(dados2); i++) {
         if (ArraySize(dados) > 0 && dados[a].tipo == dados2[i].tipo) {
            if ((dados[a].tipo == TIPO_RESISTENCIA && dados2[i].posicao > dados[a].posicao) ||
                (dados[a].tipo == TIPO_SUPORTE && dados2[i].posicao < dados[a].posicao)) {
               dados[a].index = dados2[i].index;
               dados[a].data = dados2[i].data;
               dados[a].posicao = dados2[i].posicao;
               dados[a].tipo = dados2[i].tipo;
            }
         }
         else {
            a++;
            ArrayResize(dados, ArraySize(dados) + 1);
            dados[a].index = dados2[i].index;
            dados[a].data = dados2[i].data;
            dados[a].posicao = dados2[i].posicao;
            dados[a].tipo = dados2[i].tipo;
         }
      }
   }
   return true;
}

double SR::minimaDoDia() {
   return minimaDia;
}

double SR::maximaDoDia() {
   return maximaDia;
}

ENUM_SINAL_TENDENCIA SR::tendenciaAtual(DADOS_SR& dados[], double preco) {
   ENUM_SINAL_TENDENCIA tendencia = INDEFINIDA;
   double sAtual = -1;
   double rAtual = -1;
   double sAnterior = -1;
   double rAnterior = -1;
   for (int i = ArraySize(dados) - 1; i >= 0; i--) {
      if (rAtual > 0 && rAnterior > 0 && sAtual > 0 && sAnterior > 0)
         break;
      if (dados[i].tipo == TIPO_RESISTENCIA) {
         if (rAtual > 0 && rAnterior < 0) 
            rAnterior = dados[i].posicao;
         else if (rAtual < 0) 
            rAtual = dados[i].posicao;
      }
      else if (dados[i].tipo == TIPO_SUPORTE) {
         if (sAtual > 0 && sAnterior < 0) 
            sAnterior = dados[i].posicao;
         else if (sAtual < 0) 
            sAtual = dados[i].posicao;
      }
   }
   if (sAtual > sAnterior && rAtual > rAnterior && preco > sAtual)
      tendencia = ALTA;
   if (sAtual < sAnterior && rAtual < rAnterior && preco < rAtual)
      tendencia = BAIXA;
   return tendencia;
}

double SR::suporteAtual(DADOS_SR& dados[]) {
   double suporte = -1;
   for (int i = ArraySize(dados) - 1; i >= 0; i--) {
      if (dados[i].tipo == TIPO_SUPORTE) {
         suporte = dados[i].posicao;
         break;
      }
   }  
   return suporte;
}

double SR::resistenciaAtual(DADOS_SR& dados[]) {
   double resistencia = -1;
   for (int i = ArraySize(dados) - 1; i >= 0; i--) {
      if (dados[i].tipo == TIPO_RESISTENCIA) {
         resistencia = dados[i].posicao;
         break;
      }
   }  
   return resistencia;
}

void SR::escreverLog(string msg){
   Print(msg);
}
