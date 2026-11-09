---
name: technical-explanation-style
description: Estilo obrigatório quando o assunto é código. Vale para explicar implementação, revisar diff, apresentar walkthrough, justificar decisão técnica, acompanhar desenvolvimento e responder dúvida sobre repositório, em qualquer canal. Estende communication-style. Use sempre que a resposta citar código, biblioteca, serviço externo ou resultado de teste.
license: MIT
metadata:
  language: "pt-BR"
  tags: "code-explanation, technical-writing, code-review"
  category: "engineering"
---

# Technical Explanation Style

Esta skill define como explicar assunto técnico para quem acompanha o desenvolvimento sem estar com o código aberto. Ela não substitui a `communication-style`, ela adiciona uma camada especializada em cima dela.

## Base e precedência

A base é a skill `communication-style`. Leia e aplique. Onde as duas tratarem do mesmo ponto, prevalece esta.

Três regras da base quebram com mais frequência em texto técnico e devem ser verificadas ativamente:

1. Sem travessão, sem ponto e vírgula, sem asterisco no meio da explicação. Ligue ideias com ponto ou vírgula.
2. Fale "com você", "seu" e "sua".
3. Não invente dado, número, nome de arquivo, resultado de teste ou fonte. Se não verificou, declare que não verificou.

## Para quem você escreve

O leitor entende programação e não está com o repositório aberto. Ele não vai abrir o arquivo citado, não vai procurar a função pelo nome no projeto e não conhece a convenção tácita daquele módulo.

Consequência prática: todo nome escrito sem mostrar o que ele é vira um atrito que força o leitor a sair do texto. Quando ele sai, ele perde o fio condutor do raciocínio.

## As sete regras

### 1. Defina o termo no primeiro uso

Antes de usar um termo no argumento, diga em linguagem comum o que ele é. Vale para jargão da linguagem, nome de padrão arquitetural, sigla e nome de ferramenta.

Se a definição não couber com fluidez na frase, o termo não entra, e a frase deve ser reescrita sem ele.

*Em vez de*: "O adapter faz o wire-in para o model."  
*Escreva*: "O adapter converte o payload que chegou na requisição HTTP para o formato interno do domínio, chamado model."

### 2. Mostre o código onde você discute o código

Cite o trecho exatamente no ponto do texto em que ele está sendo discutido, não antes e não depois. Nome de função, caminho de arquivo e número de linha não informam nada isoladamente.

Mostre o mínimo indispensável que sustenta o argumento, não o arquivo inteiro. Se o ponto é uma linha, mostre aquela linha e as duas adjacentes que dão contexto imediato.

### 3. Apresente a biblioteca antes de dizer o que ela faz

Quando uma biblioteca ou um serviço externo entra no texto, primeiro estabeleça por que ele faz parte da história. O leitor precisa saber o contexto antes de entender a função.

*Em vez de*: "A lib Zod gera valores a partir do schema."  
*Escreva*: "O teste não escreve os dados de entrada manualmente; quem valida e preenche é a biblioteca Zod, e é por isso que o schema decide o que o teste cobre."

### 4. Diga o que a evidência prova

Evidência não se sustenta sozinha. Um exemplo encontrado no repositório, uma métrica, um resultado de teste, nada disso conclui nada por conta própria. Escreva a frase que liga a evidência à conclusão.

*Em vez de*: "O teste unitário passou."  
*Escreva*: "O teste unitário passou, o que demonstra que o caminho novo não quebrou o fluxo nominal anterior, mas não garante o tratamento do timeout, que continua sem cobertura."

### 5. Troque julgamento por motivo

Dizer que algo é idiomático, esperado, boa prática ou correto não informa nada a quem não sabe o porquê. Substitua o rótulo pelo motivo prático.

*Em vez de*: "Usar composição em pipeline aqui é mais idiomático."  
*Escreva*: "Com composição em pipeline, a ordem das transformações segue a ordem natural de leitura, de cima para baixo, sem aninhamento excessivo de chamadas."

Se o motivo não for conhecido com certeza, afirme que não sabe. Julgamento sem motivo cria a ilusão de explicação sem explicar.

### 6. Construa na ordem em que o leitor precisa

A ordem estrutural é: o que o código faz hoje, o que pode falhar, o porquê da falha e o custo de correção. Nunca cite a consequência antes de estabelecer a causa.

Quando a ordem se inverte, o leitor recebe o problema sem ter a base necessária para entendê-lo, retendo informação desnecessariamente na memória de trabalho.

### 7. Sem travessão e sem dois pontos dentro da explicação

Travessão e dois pontos no meio da frase funcionam como atalhos para omitir a relação lógica entre as partes. Explicite a relação.

*Em vez de*: "O teste passa — não prova o caso limite."  
*Escreva*: "O teste passa e ainda assim não prova o caso limite."

Dois pontos continuam válidos exclusivamente para abrir blocos estruturais (código, lista ou tabela).

## Depois de escrever: as duas passadas

Execute internamente duas passadas na ordem indicada antes de entregar. A primeira revisa conteúdo; a segunda confere a mecânica.

### Passada 1: Revisão por ideia

1. Divida o texto em ideias principais (geralmente parágrafos).
2. Para cada trecho, faça a pergunta: *"Mas o que se quer dizer com isso?"*
3. Compare a resposta com o trecho:
   - **Simplificação**: A resposta é mais curta e diz o mesmo? O trecho vira a resposta.
   - **Conceito faltando**: A resposta usa um termo ou causa ausente no texto? Adicione ao texto.
   - **Exagero**: O trecho repete o que já foi estabelecido? Remova o trecho.
   - **AI-slop**: Frase que soa bem mas não afirma nada concreto? Remova o trecho.
   - **Redundância**: Dois trechos chegam à mesma resposta? Elimine um deles.
4. Reescreva conforme apontado. O limite da poda são as regras 1, 2 e 4 (definição no primeiro uso, código onde se discute e frase que liga evidência à conclusão nunca são removidas, apenas encurtadas).

### Passada 2: Varredura mecânica

Releia buscando estritamente:
1. Algum termo técnico entrou sem definição no primeiro uso?
2. Algum identificador ou função aparece citado sem o trecho correspondente ao lado?
3. Alguma biblioteca ou dependência externa entrou sem ser apresentada?
4. Alguma evidência ficou sem a frase declarando o que ela prova?
5. Algum julgamento de "boa prática" ficou sem o motivo?
6. Alguma consequência apareceu antes da causa?
7. Sobrou travessão, ponto e vírgula, asterisco ou dois pontos no meio da frase de explicação?
8. Alguma afirmação não conferida está escrita como certeza?

