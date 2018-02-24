//
//  ViewController.swift
//  DistributedCalculator
//
//  Created by Илья Халяпин on 23.02.2018.
//  Copyright © 2018 Ilia Khaliapin. All rights reserved.
//

import Cocoa
import SwiftSocket

class ViewController: NSViewController {
    
    // MARK: - Outlet
    
    /// Порт
    @IBOutlet private weak var portTextField: NSTextField!
    
    /// Путь к файлу
    @IBOutlet private weak var listFilePathControl: NSPathControl!
    
    /// IP сервера
    @IBOutlet private weak var serverIpTextField: NSTextField! {
        willSet {
            DispatchQueue.global().async { [weak self, newValue] in
                let ipAddress = self?.getWiFiAddress()
                
                DispatchQueue.main.async {
                    newValue?.stringValue = ipAddress ?? ""
                }
            }
        }
    }
    
    /// Кнопка "Запустить сервер"
    @IBOutlet private weak var serverStartButton: NSButton!
    /// Кнопка "Остановить сервер"
    @IBOutlet private weak var serverStopButton: NSButton! {
        willSet {
            newValue.isEnabled = false
        }
    }
    
    /// Путь к файлу
    @IBOutlet private weak var configurationFilePathControl: NSPathControl!
    
    /// Лог
    @IBOutlet private weak var logTextView: NSTextView! {
        willSet {
            newValue.isEditable = false
        }
    }
    
    
    // MARK: - Приватные свойства
    
    private var queue = DispatchQueue(label: "ru.ilyahal.queue", qos: .utility, attributes: .concurrent)
    
    /// URL файла с конфигурацией
    private var configurationUrl: URL? {
        willSet {
            self.configurationFilePathControl.url = newValue
        }
    }
    /// URL файла со списком IP
    private var listUrl: URL? {
        willSet {
            self.listFilePathControl.url = newValue
        }
    }
    
    /// Сервер
    private var server: TCPServer?

}


// MARK: - Приватные свойства

private extension ViewController {
    
    /// Порт
    var port: Int32 {
        return self.portTextField.intValue
    }
    
    /// IP сервера
    var serverIp: String {
        return self.serverIpTextField.stringValue
    }
    
    /// Случайный IP
    var randomIp: String? {
        guard let list = getList() else { return nil }
        
        let index = Int(arc4random_uniform(UInt32(list.count - 1)))
        return list[index]
    }
    
}


// MARK: - NSViewController

extension ViewController {
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        self.view.window?.delegate = self
        self.view.window?.makeFirstResponder(nil)
    }
    
}


// MARK: - Action

private extension ViewController {
    
    /// Нажата кнопка "Выбрать список"
    @IBAction func selectListFileButtonClicked(_ sender: NSButton) {
        let dialog = NSOpenPanel()
        dialog.title = "Выберите JSON со списком IP"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["json"]
        
        if dialog.runModal() == .OK {
            guard let url = dialog.url else { return }
            self.listUrl = url
        }
    }
    
    /// Нажата кнопка "Запустить сервер"
    @IBAction func serverStartClicked(_ sender: NSButton) {
        let port = self.port
        let serverIp = self.serverIp
        
        self.queue.async {
            self.startServer(serverIp: serverIp, port: port)
        }
        
        sender.isEnabled = false
        self.serverStopButton.isEnabled = true
    }
    
    /// Нажата кнопка "Остановить сервер"
    @IBAction func serverStopClicked(_ sender: NSButton) {
        self.server?.close()
        self.server = nil
        
        sender.isEnabled = false
        self.serverStartButton.isEnabled = true
    }
    
    /// Нажата кнопка "Выбрать конфигурацию"
    @IBAction func selectConfigurationFileButtonClicked(_ sender: NSButton) {
        let dialog = NSOpenPanel()
        dialog.title = "Выберите JSON с конфигурацией"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["json"]
        
        if dialog.runModal() == .OK {
            guard let url = dialog.url else { return }
            self.configurationUrl = url
        }
    }
    
    /// Нажата кнопка "Начать вычисление"
    @IBAction func runCalculation(_ sender: NSButton) {
        let port = self.port
        
        guard let configuration = getConfiguration() else { return }
        guard let randomIp = self.randomIp else { return }
        
        self.queue.async {
            self.startClient(clientIp: randomIp, port: port, configuration: configuration)
        }
    }
    
}


// MARK: - Приватные методы

private extension ViewController {
    
    /// Получение IP-адреса
    func getWiFiAddress() -> String? {
        var address: String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
    
    /// Лог
    func log(message: String) {
        DispatchQueue.main.async {
            self.logTextView.string += message + "\n"
            self.logTextView.scrollToEndOfDocument(self)
        }
    }
    
    /// Получить список IP
    func getList() -> [String]? {
        guard let listUrl = self.listUrl, let data = try? Data(contentsOf: listUrl) else { return nil }
        
        let decoder = JSONDecoder()
        guard let list = try? decoder.decode([String].self, from: data) else { return nil }
        
        return list
    }
    
    /// Получить конфигурацию
    func getConfiguration() -> Configuration? {
        guard let configurationUrl = self.configurationUrl, let data = try? Data(contentsOf: configurationUrl) else { return nil }
        
        let decoder = JSONDecoder()
        guard let configuration = try? decoder.decode(Configuration.self, from: data) else { return nil }
        
        return configuration
    }
    
    /// Выполнить операцию
    func performOperation(configuration: Configuration) {
        guard configuration.parameters.first?.action == "r" else { return }
        let parameter = configuration.parameters.removeFirst()
        
        if parameter.value == 0 {
            configuration.enteringNumber = 0
        } else {
            let result = pow(configuration.enteringNumber, 1.0 / parameter.value)
            configuration.enteringNumber = result
        }
    }
    
    /// Запустить клиента
    func startClient(clientIp: String, port: Int32, configuration: Configuration) {
        let client = TCPClient(address: clientIp, port: port)
        switch client.connect(timeout: 10) {
        case .success:
            defer { client.close() }
            
            log(message: "IP-адрес получателя: \(clientIp)")
            log(message: "Количество операций: \(configuration.parameters.count)")
            log(message: "Входящее число: \(configuration.enteringNumber)")
            log(message: "Первая операция: \(configuration.parameters.first?.action ?? "") \(configuration.parameters.first?.value ?? 0)")
            log(message: "")
            
            guard let data = configuration.data else { return }
            
            switch client.send(data: data) {
            case .success:
                log(message: "Данные успешно отправлены: \(data)")
            case .failure(let error):
                log(message: "Ошибка при отправке данных получателю: \(error.localizedDescription)")
            }
        case .failure(let error):
            log(message: "Ошибка при подключении к получателю: \(error.localizedDescription)")
            
            guard let randomIp = self.randomIp else { return }
            self.queue.async {
                self.startClient(clientIp: randomIp, port: port, configuration: configuration)
            }
        }
        
        log(message: "")
    }
    
    /// Запустить сервер
    func startServer(serverIp: String, port: Int32) {
        self.server?.close()
        
        let server = TCPServer(address: serverIp, port: port)
        self.server = server
        
        switch server.listen() {
        case .success:
            while server.fd != nil {
                guard let client = server.accept() else {
                    log(message: "Ошибка при подключении отправителя")
                    continue
                }
                defer { client.close() }
                
                log(message: "IP-адрес отправителя: \(client.address)")
                
                guard let bytes = client.read(1024 * 10) else {
                    log(message: "Ошибка при чтении данных от отправителя")
                    continue
                }
                
                let data = Data(bytes)
                guard let configuration = Configuration(data: data) else {
                    log(message: "Входящие данные имеют неверный формат")
                    continue
                }
                
                log(message: "Количество операций: \(configuration.parameters.count)")
                log(message: "Входящее число: \(configuration.enteringNumber)")
                log(message: "Первая операция: \(configuration.parameters.first?.action ?? "") \(configuration.parameters.first?.value ?? 0)")
                log(message: "")
                
                performOperation(configuration: configuration)
                
                if configuration.parameters.first?.action == "=" {
                    log(message: "Результат вычислений: \(configuration.enteringNumber)")
                    log(message: "")
                    
                    NSSound.beep()
                } else {
                    guard let randomIp = self.randomIp else { continue }
                    
                    self.queue.async {
                        self.startClient(clientIp: randomIp, port: port, configuration: configuration)
                    }
                }
            }
        case .failure(let error):
            log(message: "Ошибка: \(error.localizedDescription)")
        }
    }
    
}


// MARK: - NSWindowDelegate

extension ViewController: NSWindowDelegate {
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApplication.shared.terminate(nil)
        return true
    }
    
}
