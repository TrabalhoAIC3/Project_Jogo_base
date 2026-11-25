# Survival Arena

Jogo 2D feito em Godot com duas partes para demonstração: um lobby multiplayer pela internet e uma arena experimental com agentes de inteligência artificial.

## Abrir o jogo

1. Abra o projeto no **Godot 4.7.2 .NET**.
2. Aguarde a importação e a compilação inicial.
3. Pressione **F6** para executar a cena aberta ou **F5** para iniciar o projeto.

A cena principal abre o lobby. Para experimentar a arena local com inimigos, abra `test_scene.tscn` e pressione **F6**. A arena de duelo com agentes de IA está em `DuelArena.tscn`.

No notebook preparado para a apresentação, use o atalho **Survival Arena (Godot)** no menu de aplicativos; ele abre este projeto no editor.

## Baixar para testar

    git clone --branch apresentacao --single-branch https://github.com/TrabalhoAIC3/Project_Jogo_base.git
    cd Project_Jogo_base

## Multiplayer

O lobby conecta ao servidor WebSocket configurado em `websocket_client.gd`. Ele permite criar uma sala, entrar com o código, marcar-se como pronto e iniciar a partida. Use uma conexão com a internet; o servidor hospedado pode levar alguns instantes para responder quando estiver inativo.

Para apontar a outra instância do jogo para outro servidor, inicie o Godot com um argumento de usuário, por exemplo:

    --server=wss://seu-servidor.example

## Requisitos

- Godot Engine 4.7.2 com suporte a .NET.
- .NET SDK 8.0 ou superior para compilar o projeto Godot.
- .NET SDK 10.0 para executar o servidor local em `server/`.

O modelo ONNX usado pela arena de IA já está incluído; não é necessário instalar Python para jogar.

## Servidor local (opcional)

Com o SDK .NET 10 instalado, execute:

    dotnet run --project server/AicIv.Server.csproj

Na pasta do projeto, inicie o jogo com:

    godot --path . -- --server=ws://127.0.0.1:8080

## Conteúdo do projeto

- `lobby.tscn`, `lobby.gd`, `websocket_client.gd`: lobby, conexão e interface multiplayer.
- `server/`: servidor de salas e partida.
- `test_scene.tscn`: arena de sobrevivência com Game Over e XP.
- `DuelArena.tscn`, `rl/`, `models/`: arena e agentes de IA com ONNX.
- `addons/godot_rl_agents/`: complemento Godot RL Agents.
