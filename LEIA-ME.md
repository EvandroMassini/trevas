# TREVAS — O Guardião do Labirinto

Jogo original em assembly Z80, inspirado na exploração em primeira pessoa e na perseguição de Monster Maze. Destinado ao Microdigital TK95 e ao ZX Spectrum 48K. Código, labirintos, fonte e desenhos próprios; não contém código, ROM ou gráficos do jogo antigo.

## Jogar agora

No emulador, escolha **ZX Spectrum 48K** ou **TK95**, se disponível, e abra `build/trevas.sna`. O snapshot começa na entrada do programa e mostra a apresentação. Pressione e solte **SPACE**.

Também é possível montar `build/trevas.tap`, digitar `LOAD ""` e iniciar a fita virtual. O carregador BASIC executa o jogo automaticamente. Em máquinas com outros modos, use o modo 48K. O programa ocupa a máquina até um reset.

No TK95 físico, conecte a saída de áudio à entrada **EAR**, digite `LOAD ""` e reproduza `build/trevas.wav` inteiro, sem efeitos ou alterações de velocidade. O áudio PCM mono de 44,1 kHz dura aproximadamente dois minutos. Ajuste o volume conforme a resposta da entrada de fita do seu computador. `.sna` é um snapshot para emuladores; não é áudio de carga.

## Objetivo e comandos

Encontre os **três selos amarelos**, recolhidos ao entrar em suas casas, e alcance o **portal verde**. Ele só permite escapar quando todos os selos foram recolhidos. O guardião vermelho percorre o labirinto atrás de você; encostar nele encerra a partida.

| Tecla | Ação |
|---|---|
| Q / A | Avançar / recuar |
| O / P | Girar à esquerda / direita |
| SPACE | Iniciar; durante o jogo, usar um pulso de atordoamento |
| M | Alternar visão em primeira pessoa e mapa explorado |
| H | Pausar ou continuar |

Você dispõe de **dois pulsos por partida**. Cada pulso paralisa o guardião por 110 interrupções de vídeo, aproximadamente 1,8–2,2 segundos. O efeito é global, mas o contato com o monstro continua fatal. O mapa **não pausa** a perseguição. O losango sólido marca sua posição; o pequeno losango vazado representa um selo; o quadrado com centro representa o portal. A bússola usa N, L, S e O.

Os bipes se tornam mais frequentes quando diminui a distância de percurso até o guardião. Há uma folga inicial de aproximadamente 3–4 segundos, e ele acelera a cada selo recolhido. Use cruzamentos, recuos e o mapa para planejar a fuga. Pausar congela a simulação, inclusive a contagem do atordoamento.

## Recursos

- Perspectiva de quatro níveis em uma janela de 256 × 128 pixels, com alvenaria e passagens laterais.
- Cores por célula do Spectrum: arquitetura ciano, selos amarelos, saída verde e guardião vermelho.
- Três labirintos com circuitos alternativos, selecionados pelo instante de início. São mapas pré-gerados, não geração ilimitada durante a partida.
- Perseguição por busca em largura: o guardião segue o caminho mais curto, incluindo curvas.
- Mapa que registra casas e paredes observadas; bússola, contagem de selos e alertas de proximidade.
- Sons no beeper pela porta FE, sem depender de AY ou expansões.
- Pausa, reinício após vitória/derrota e repetição de movimento ao segurar uma tecla.

## Fluidez e compatibilidade

A movimentação é **por casas e giros de 90 graus**, sem rotação ou caminhada interpolada. Gráficos pré-calculados, desenho em buffer na RAM superior, limpeza rápida por pilha e cópia desenrolada evitam apagar a tela antes de desenhar. A tela é atualizada quando o estado muda. Não há troca física de páginas de vídeo no 48K: a cópia ainda pode produzir algum tearing.

Os testes de CPU mediram cerca de **350–363 mil T-states nas cenas mais custosas**, aproximadamente 0,10 segundo de CPU a 3,5 MHz, antes da contenção da ULA e do restante do laço. Isso não equivale a uma medição de FPS no aparelho. Os temporizadores contam interrupções: em uma máquina de 60 Hz a perseguição e os pulsos ficam mais rápidos que em uma de 50 Hz.

O jogo usa somente instruções Z80 documentadas, tela e teclado do Spectrum e beeper; após a carga, não faz chamadas à ROM. Foram executados testes em CPU Z80 emulada com interrupções de 50 e 60 Hz. **Ainda não foi validado em um TK95 físico nem em uma emulação completa da ULA/ROM.** A carga analógica, o som ouvido e o tempo real de vídeo precisam dessa validação.

## Conteúdo

| Arquivo | Finalidade |
|---|---|
| `build/trevas.tap` | Fita com carregador BASIC e código |
| `build/trevas.sna` | Snapshot 48K para abrir rapidamente |
| `build/trevas.wav` | Áudio da fita para a entrada EAR |
| `build/trevas.bin` | Binário com origem em 32768 |
| `trevas.asm` | Código assembly do jogo |
| `assets.inc` | Gráficos, fonte e mapas em dados assembly |
| `tools/assets.cjs` | Gerador dos dados; não é executado no TK95 |
| `tools/test.cjs` | Testes que executam o binário em uma CPU Z80 |
| `build/*hz.json` | Relatórios dos testes |
| `build/*.png` e `build/*.scr` | Telas produzidas pela execução Z80 de teste |

A captura do guardião é uma situação preparada pelo teste. A captura do mapa ocorre depois de visitar as casas durante a verificação; uma partida nova começa com o mapa quase todo oculto.

## Compilar e testar

Requer Node.js 18 ou posterior e acesso ao npm para instalar Pasmo e a CPU de teste. Na pasta deste projeto:

```sh
npm ci
npm run build
npm test
npm run audio
node tools/validate-audio.cjs
npm run screens
```

Para repetir os testes com interrupções de 60 Hz no PowerShell:

```powershell
$env:TEST_HZ = "60"
npm test
Remove-Item Env:TEST_HZ
```

Também é possível usar o Pasmo nativo, com `assets.inc` já fornecido:

```sh
pasmo --tapbas trevas.asm build/trevas.tap
pasmo --bin trevas.asm build/trevas.bin build/trevas.symbols
```

O jogo inteiro executado no TK95 está em assembly. JavaScript serve apenas para gerar assets, montar arquivos e testar no computador de desenvolvimento. O teste verifica conectividade dos mapas, selos e portal, bloqueio de paredes, distâncias, perseguição, quatro direções em cada casa transitável, vitória pelo movimento real, derrota, pulsos, leitura de teclas, pausa, fita e snapshot. A verificação de áudio decodifica o WAV de volta aos quatro blocos TAP e compara byte a byte.

Mapa de memória: código/dados em `8000h–C86Ah` aproximadamente; buffer em `E000h–EFFFh`; distâncias em `F200h`; fila em `F300h`; mapa em `F400h`; exploração em `F500h`; pilha abaixo de `FD00h`; salto de interrupção em `FDFDh`; tabela IM2 em `FE00h–FF00h`. O build rejeita qualquer crescimento do código até o buffer.

## Referências de implementação

- [Manual da CPU Z80 — Zilog](https://www.zilog.com/docs/z80/um0080.pdf).
- [Manual de operação Microdigital TK90X — digitalização](https://trastero.speccy.org/cosas/manuales/TK90X_Manual_de_Operacao.pdf), para comandos e conexão de cassete da família.
- [Manual técnico do Spectrum — circuito de teclado e fita](https://worldofspectrum.org/hardware/rep5.html).
- [Pasmo, distribuição Emscripten](https://github.com/stever/emscripten-pasmo).
- [CPU Z80 usada nos testes](https://github.com/lkesteloot/trs80/tree/master/packages/z80-emulator).

O código original deste projeto é distribuído sob a licença MIT. As ferramentas de desenvolvimento mantêm suas próprias licenças; não são incorporadas ao binário Z80.
