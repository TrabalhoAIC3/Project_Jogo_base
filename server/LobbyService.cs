using System.Security.Cryptography;
using System.Text.Json;

namespace AicIv.Server;

// Serializa alterações e notificações para manter todos os clientes na mesma ordem.
internal sealed class LobbyService(Func<string, object, CancellationToken, Task> send)
{
    private readonly SemaphoreSlim gate = new(1, 1);
    private readonly Dictionary<string, Room> rooms = new();
    private readonly Dictionary<string, string> memberships = new();
    private const int Capacity = 2;

    public async Task HandleAsync(string id, string type, JsonElement message, CancellationToken token)
    {
        await gate.WaitAsync(token);
        try
        {
            if (type == "lobby_list")
            {
                await send(id, new { type = "rooms_list", rooms = rooms.Values.Where(r => !r.Started)
                    .Select(r => new { code = r.Code, host_name = r.Players[0].Name,
                        player_count = r.Players.Count, capacity = Capacity }).ToArray() }, token);
                return;
            }
            if (type == "room_leave")
            {
                await RemoveAsync(id, token);
                await send(id, new { type = "room_left" }, token);
                return;
            }
            if (type is "room_create" or "room_join")
            {
                if (memberships.ContainsKey(id)) { await Error(id, "Você já está em uma sala.", token); return; }
                var name = Text(message, "name").Trim();
                if (name.Length is < 1 or > 24 || name.Any(char.IsControl))
                { await Error(id, "Use um nome entre 1 e 24 caracteres.", token); return; }
                Room room;
                if (type == "room_create")
                {
                    if (rooms.Count >= 128) { await Error(id, "Limite de salas atingido.", token); return; }
                    string code;
                    do { code = Convert.ToHexString(RandomNumberGenerator.GetBytes(3)); } while (rooms.ContainsKey(code));
                    room = new Room(code, id);
                    rooms.Add(code, room);
                }
                else
                {
                    var code = Text(message, "code").Trim().ToUpperInvariant();
                    if (!rooms.TryGetValue(code, out room!)) { await Error(id, "Sala não encontrada.", token); return; }
                    if (room.Started) { await Error(id, "Esta partida já começou.", token); return; }
                    if (room.Players.Count >= Capacity) { await Error(id, "A sala está cheia.", token); return; }
                }
                room.Players.Add(new Player(id, name));
                memberships.Add(id, room.Code);
                await NotifyAsync(room, "room_state", token);
                return;
            }
            if (!memberships.TryGetValue(id, out var roomCode))
            { await Error(id, "Entre em uma sala primeiro.", token); return; }
            var current = rooms[roomCode];
            if (current.Started && type is not ("game_move" or "game_state" or "enemy_hit" or "xp_collect"))
            { await Error(id, "Esta partida já começou.", token); return; }
            if (type == "game_move")
            {
                if (!message.TryGetProperty("x", out var x) || !message.TryGetProperty("y", out var y)
                    || x.ValueKind != JsonValueKind.Number || y.ValueKind != JsonValueKind.Number)
                { await Error(id, "Posição inválida.", token); return; }
                var player = current.Players.Single(p => p.Id == id);
                player.X = Math.Clamp(x.GetSingle(), -10000, 10000);
                player.Y = Math.Clamp(y.GetSingle(), -10000, 10000);
                await NotifyAsync(current, "player_move", token);
                return;
            }
            if (type == "game_state")
            {
                if (current.HostId != id) { await Error(id, "Somente o anfitrião pode atualizar o mundo.", token); return; }
                if (!message.TryGetProperty("enemies", out var enemies) || enemies.ValueKind != JsonValueKind.Array
                    || enemies.GetArrayLength() > 256
                    || !message.TryGetProperty("gems", out var gems) || gems.ValueKind != JsonValueKind.Array
                    || gems.GetArrayLength() > 256)
                { await Error(id, "Estado do mundo inválido.", token); return; }

                current.ActiveGems.Clear();
                foreach (var gem in gems.EnumerateArray())
                {
                    if (!gem.TryGetProperty("id", out var gemIdValue) || gemIdValue.ValueKind != JsonValueKind.String)
                        continue;
                    var gemId = gemIdValue.GetString()!;
                    if (gemId.Length is < 1 or > 128 || current.CollectedGems.Contains(gemId))
                        continue;
                    current.ActiveGems[gemId] = gem.Clone();
                }

                var gameState = new
                {
                    type = "game_state",
                    enemies,
                    gems = current.ActiveGems.Values.ToArray()
                };
                await Task.WhenAll(current.Players.Where(p => p.Id != id)
                    .Select(p => send(p.Id, gameState, token)));
                return;
            }
            if (type == "enemy_hit")
            {
                if (id != current.HostId)
                {
                    var enemyId = Text(message, "enemy_id");
                    if (enemyId.Length is < 1 or > 128
                        || !message.TryGetProperty("damage", out var damageValue)
                        || !damageValue.TryGetInt32(out var damage) || damage is < 1 or > 100)
                    { await Error(id, "Acerto de inimigo inválido.", token); return; }
                    await send(current.HostId, new { type = "enemy_hit", enemy_id = enemyId, damage }, token);
                }
                return;
            }
            if (type == "xp_collect")
            {
                var gemId = Text(message, "gem_id");
                if (gemId.Length is < 1 or > 128 || !current.ActiveGems.TryGetValue(gemId, out var gem))
                    return;
                if (!current.CollectedGems.Add(gemId))
                    return;
                current.ActiveGems.Remove(gemId);
                var amount = gem.TryGetProperty("amount", out var amountValue) && amountValue.TryGetInt32(out var value)
                    ? Math.Clamp(value, 1, 1000) : 10;
                var collected = new { type = "xp_collected", gem_id = gemId, player_id = id, amount };
                await Task.WhenAll(current.Players.Select(p => send(p.Id, collected, token)));
                return;
            }
            if (type == "room_ready")
            {
                if (!message.TryGetProperty("ready", out var ready) || ready.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                { await Error(id, "O estado pronto deve ser verdadeiro ou falso.", token); return; }
                current.Players.Single(p => p.Id == id).Ready = ready.GetBoolean();
                await NotifyAsync(current, "room_state", token);
            }
            else if (type == "game_start")
            {
                if (current.HostId != id) { await Error(id, "Somente o anfitrião pode iniciar.", token); return; }
                if (current.Players.Any(p => !p.Ready)) { await Error(id, "Todos devem marcar Pronto.", token); return; }
                current.Started = true;
                await NotifyAsync(current, "game_started", token);
            }
            else { await Error(id, "Comando de lobby desconhecido.", token); }
        }
        finally { gate.Release(); }
    }

    public async Task DisconnectAsync(string id)
    {
        await gate.WaitAsync();
        try { await RemoveAsync(id, CancellationToken.None); }
        finally { gate.Release(); }
    }

    private async Task RemoveAsync(string id, CancellationToken token)
    {
        if (!memberships.Remove(id, out var code)) return;
        var room = rooms[code];
        room.Players.RemoveAll(p => p.Id == id);
        if (room.Players.Count == 0) { rooms.Remove(code); return; }
        if (room.HostId == id) room.HostId = room.Players[0].Id;
        await NotifyAsync(room, "room_state", token);
    }

    private Task NotifyAsync(Room room, string type, CancellationToken token)
    {
        var snapshot = new { code = room.Code, host_id = room.HostId, started = room.Started,
            capacity = Capacity, players = room.Players.Select(p => new { id = p.Id, name = p.Name, ready = p.Ready, x = p.X, y = p.Y }).ToArray() };
        return Task.WhenAll(room.Players.Select(p => send(p.Id, new { type, room = snapshot }, token)));
    }

    private Task Error(string id, string message, CancellationToken token) =>
        send(id, new { type = "error", message }, token);
    private static string Text(JsonElement message, string key) =>
        message.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString()! : "";

    private sealed class Room(string code, string hostId)
    {
        public string Code { get; } = code;
        public string HostId { get; set; } = hostId;
        public bool Started { get; set; }
        public List<Player> Players { get; } = new();
        public Dictionary<string, JsonElement> ActiveGems { get; } = new(StringComparer.Ordinal);
        public HashSet<string> CollectedGems { get; } = new(StringComparer.Ordinal);
    }
    private sealed class Player(string id, string name)
    {
        public string Id { get; } = id;
        public string Name { get; } = name;
        public bool Ready { get; set; }
        public float X { get; set; }
        public float Y { get; set; }
    }
}
