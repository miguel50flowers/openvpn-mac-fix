import Foundation

let args = CommandLine.arguments.dropFirst()
let client = CLIXPCClient()
client.connect()

guard let command = args.first else {
    Commands.help()
    exit(0)
}

switch command {
case "status":
    Commands.status(client: client)
case "diagnose":
    Commands.diagnose(client: client)
case "fix":
    let subArgs = Array(args.dropFirst())
    if subArgs.first == "--all" || subArgs.isEmpty {
        Commands.fixAll(client: client)
    } else {
        Commands.fixClient(subArgs[0], client: client)
    }
case "version":
    Commands.version(client: client)
case "help", "--help", "-h":
    Commands.help()
default:
    fputs("Unknown command: \(command)\n", stderr)
    Commands.help()
    exit(1)
}
