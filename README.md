# Survival Arena — Inteligência Artificial

Projeto experimental de uma arena 2D desenvolvida com Godot Engine e Godot RL Agents. O objetivo é testar personagens controlados por inteligência artificial utilizando aprendizado por reforço.

## Personagens

- **Shooter (azul):** utiliza projéteis e ataques à distância.
- **KnifeFighter (vermelho):** persegue o adversário e utiliza ataques corpo a corpo.

Os dois personagens lutam de forma autônoma.

## Tecnologias

- Godot Engine 4.7.2 .NET
- C# e .NET 8
- GDScript
- Godot RL Agents
- ONNX Runtime
- Stable-Baselines3 e PPO

Complemento utilizado:
https://github.com/edbeeching/godot_rl_agents

## Requisitos

- Godot Engine 4.7.2 com suporte a .NET.
- .NET SDK 8.0 ou superior.
- Git.

**Importante:** utilize a versão .NET do Godot, não a versão padrão sem suporte a C#.

Não é necessário instalar Python para executar a arena. O modelo ONNX já está incluído no projeto.

## Como baixar

Clone a branch atual:

    git clone --branch jadson/game-over-xp --single-branch https://github.com/TrabalhoAIC3/Project_Jogo_base.git

Entre na pasta:

    cd Project_Jogo_base

## Como preparar o projeto

Restaure as dependências:

    dotnet restore "Godot RL Agents.csproj"

Compile o projeto:

    dotnet build "Godot RL Agents.csproj"

## Como executar

1. Abra o projeto no Godot 4.7.2 .NET.
2. Aguarde a importação dos arquivos e a compilação dos scripts.
3. Abra a cena `DuelArena.tscn`.
4. Pressione **F6 (Run Current Scene)** para iniciar a arena.

Também é possível executar pelo terminal:

    godot --path . res://DuelArena.tscn

Substitua `godot` pelo comando correspondente à instalação no seu sistema, caso necessário.

## Modelo de inteligência artificial

A arena utiliza o modelo:

`models/duel_training_20261031_175756.onnx`

O modelo foi treinado com aprendizado por reforço e exportado para ONNX. Ele é utilizado para controlar os agentes durante os confrontos.

## Estado atual

Esta é uma versão experimental. Os agentes já conseguem lutar de forma autônoma, mas o comportamento ainda pode ser aperfeiçoado.

O Shooter pode avançar em direção ao adversário em algumas situações, em vez de manter sempre a distância esperada. Os resultados dos confrontos podem variar.

## Estrutura principal

- `addons/`: complemento Godot RL Agents.
- `Font/attack/`: recursos do ataque Ice Spear.
- `models/`: modelo ONNX utilizado pela arena.
- `rl/`: scripts dos agentes e controladores.
- `DuelArena.tscn`: cena principal.
- `project.godot`: configuração do projeto.
- `Godot RL Agents.csproj`: configuração do projeto C#.

O ambiente virtual Python, os logs, os checkpoints de treinamento e os arquivos de backup não são necessários para executar a arena e não fazem parte da publicação.
