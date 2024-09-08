import Foundation
import Starscream

class WebSocketManager: WebSocketDelegate {
    var socket: WebSocket!

    init() {
        var request = URLRequest(url: URL(string: "ws://localhost:8080")!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
    }

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            print("WebSocket connected: \(headers)")
        case .disconnected(let reason, let code):
            print("WebSocket disconnected: \(reason) with code: \(code)")
        case .text(let string):
            handleWebSocketText(string)
        case .binary(let data):
            print("Received data: \(data.count) bytes")
        case .ping(_):
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            print("WebSocket cancelled")
        case .error(let error):
            print("WebSocket error: \(String(describing: error))")
        case .peerClosed:
            print("WebSocket peer closed")
        }
    }

    func handleWebSocketText(_ text: String) {
        printCurrentTime()
        let json: [String: Any] = ["text": text]
        // saveJSONToFile(json: json) // Save JSON to file
        sendToOllamaPhi(json: json)
    }

    func saveJSONToFile(json: [String: Any]) {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentDirectory = urls.first {
            let fileURL = documentDirectory.appendingPathComponent("websocket_received.json")
            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
                try data.write(to: fileURL)
                print("JSON data saved to file: \(fileURL.path)")
            } catch {
                print("Failed to save JSON data to file: \(error)")
            }
        }
    }

    func printCurrentTime() {
        let date = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        let formattedDate = formatter.string(from: date)
        print("New message received at: \(formattedDate) Pacific Time")
    }

    func sendToOllamaPhi(json: [String: Any]) {
        let userMessage = json["text"] as? String ?? ""
        let instruction = """
        Identify if the user is doing something obviously wrong or bad and tell them concisely in one sentence. Respond in one sentence only.
        """
        // let messageContent = instruction + userMessage // Unused variable

        let requestData: [String: Any] = [
            "model": "llama3.1",
            "messages": [
                ["role": "system", "content": instruction], // Detailed instruction message
                ["role": "user", "content": userMessage] // User message
            ]
        ]

        do {
            let requestDataJSON = try JSONSerialization.data(withJSONObject: requestData, options: .prettyPrinted)
            // if let requestDataString = String(data: requestDataJSON, encoding: .utf8) { // Unused variable
            //     // print("Request Data: \(requestDataString)")
            // }
        } catch {
            print("Failed to serialize requestData for printing: \(error)")
        }

        guard let url = URL(string: "http://localhost:11434/api/chat") else { 
            print("Invalid URL")
            return 
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestData, options: [])
        } catch {
            print("Failed to serialize JSON: \(error)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending data to Ollama Phi3.5: \(error)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Response Status Code: \(httpResponse.statusCode)") // Debug print
            }
            guard let data = data else {
                print("No data received from Ollama Phi3.5")
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {
                // print("Response String: \(responseString)") // Debug print
                var accumulatedResponse = ""
                let lines = responseString.split(separator: "\n")
                for line in lines {
                    if let lineData = line.data(using: .utf8) {
                        do {
                            if let jsonResponse = try JSONSerialization.jsonObject(with: lineData, options: []) as? [String: Any],
                               let message = jsonResponse["message"] as? [String: Any],
                               let responseText = message["content"] as? String {
                                accumulatedResponse += responseText
                            } else {
                                print("Invalid response format")
                            }
                        } catch {
                            print("Failed to parse response: \(error)")
                        }
                    }
                }
                print("Accumulated Response: \(accumulatedResponse)")

                // Escape the accumulated response for JSON
                let escapedResponse = accumulatedResponse
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")

                // Send the response using Process
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                process.arguments = [
                    "-X", "POST", "http://localhost:11435/notify",
                    "-H", "Content-Type: application/json",
                    "-d", "{\"title\": \"AI Boss (screenpipe)\", \"body\": \"\(escapedResponse)\"}"
                ]

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    print("Failed to execute curl command: \(error)")
                }
            }
        }
        task.resume()
    }
}
// Entry point
let webSocketManager = WebSocketManager()
RunLoop.main.run()

