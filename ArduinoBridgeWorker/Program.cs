using System.IO.Ports;
using System.Net.Http.Json;
using System.Text.Json;

static string Config(string key, string fallback = "")
{
    var env = Environment.GetEnvironmentVariable(key);
    if (!string.IsNullOrWhiteSpace(env)) return env;

    const string file = "appsettings.json";
    if (File.Exists(file))
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(file));
        if (doc.RootElement.TryGetProperty(key, out var prop))
            return prop.GetString() ?? fallback;
    }

    return fallback;
}

var apiUrl = Config("API_URL").TrimEnd('/');
var workerToken = Config("WORKER_TOKEN");
var serialPortName = Config("SERIAL_PORT", "COM7");
var baudRate = int.TryParse(Config("BAUD_RATE", "9600"), out var b) ? b : 9600;

if (string.IsNullOrWhiteSpace(apiUrl))
{
    Console.WriteLine("Configure API_URL em appsettings.json ou variável de ambiente.");
    return;
}

using var http = new HttpClient
{
    BaseAddress = new Uri(apiUrl),
    Timeout = TimeSpan.FromSeconds(10)
};

if (!string.IsNullOrWhiteSpace(workerToken))
    http.DefaultRequestHeaders.Add("X-Worker-Token", workerToken);

SerialPort? serial = null;
var pendentes = new Queue<string>();

SerialPort? AbrirSerial()
{
    try
    {
        if (serial is { IsOpen: true }) return serial;

        serial?.Dispose();
        serial = new SerialPort(serialPortName, baudRate)
        {
            ReadTimeout = 500,
            WriteTimeout = 1000,
            NewLine = "\n"
        };
        serial.Open();
        Console.WriteLine($"[Serial] Conectado em {serialPortName} @ {baudRate}.");
        return serial;
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[Serial] Não foi possível abrir {serialPortName}: {ex.Message}");
        return null;
    }
}

async Task EnviarEventoParaApi(string evento)
{
    try
    {
        var res = await http.PostAsJsonAsync("/worker/evento", new { Evento = evento });
        if (!res.IsSuccessStatusCode)
        {
            Console.WriteLine($"[API] Falha ao enviar evento {evento}: {(int)res.StatusCode}");
            pendentes.Enqueue(evento);
            return;
        }
        Console.WriteLine($"[Arduino -> API] {evento}");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[API] Sem conexão ao enviar evento {evento}: {ex.Message}");
        pendentes.Enqueue(evento);
    }
}

async Task ReenviarPendentes()
{
    if (pendentes.Count == 0) return;

    var qtd = pendentes.Count;
    for (var i = 0; i < qtd; i++)
    {
        var evento = pendentes.Dequeue();
        try
        {
            var res = await http.PostAsJsonAsync("/worker/evento", new { Evento = evento });
            if (res.IsSuccessStatusCode)
                Console.WriteLine($"[Retry -> API] {evento}");
            else
                pendentes.Enqueue(evento);
        }
        catch
        {
            pendentes.Enqueue(evento);
            break;
        }
    }
}

async Task LoopLeituraArduino(CancellationToken ct)
{
    while (!ct.IsCancellationRequested)
    {
        try
        {
            var porta = AbrirSerial();
            if (porta == null)
            {
                await Task.Delay(2000, ct);
                continue;
            }

            var linha = porta.ReadLine().Trim();
            if (!string.IsNullOrWhiteSpace(linha))
                await EnviarEventoParaApi(linha);
        }
        catch (TimeoutException)
        {
            // normal: significa que não chegou linha nova nesse intervalo
            await Task.Delay(10, ct);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Serial] Erro na leitura: {ex.Message}");
            try { serial?.Close(); } catch { }
            await Task.Delay(1000, ct);
        }
    }
}

async Task LoopComandosApi(CancellationToken ct)
{
    while (!ct.IsCancellationRequested)
    {
        try
        {
            await ReenviarPendentes();

            var cmd = await http.GetFromJsonAsync<ComandoDto>("/worker/comandos", ct);
            if (cmd is { Id: > 0 } && !string.IsNullOrWhiteSpace(cmd.Comando))
            {
                var porta = AbrirSerial();
                if (porta == null)
                {
                    await Task.Delay(1000, ct);
                    continue;
                }

                porta.WriteLine(cmd.Comando.Trim().ToUpperInvariant());
                Console.WriteLine($"[API -> Arduino] #{cmd.Id}: {cmd.Comando}");

                var res = await http.PostAsync($"/worker/comandos/{cmd.Id}/concluido", null, ct);
                if (!res.IsSuccessStatusCode)
                    Console.WriteLine($"[API] Comando enviado, mas não consegui confirmar #{cmd.Id}: {(int)res.StatusCode}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[API] Erro ao buscar comandos: {ex.Message}");
        }

        await Task.Delay(800, ct);
    }
}

Console.WriteLine("ArduinoBridgeWorker iniciado.");
Console.WriteLine($"API: {apiUrl}");
Console.WriteLine($"Serial: {serialPortName} @ {baudRate}");
Console.WriteLine("Pressione CTRL+C para encerrar.");

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) =>
{
    e.Cancel = true;
    cts.Cancel();
};

await Task.WhenAll(
    LoopLeituraArduino(cts.Token),
    LoopComandosApi(cts.Token)
);

public sealed class ComandoDto
{
    public int Id { get; set; }
    public string Comando { get; set; } = "";
}
