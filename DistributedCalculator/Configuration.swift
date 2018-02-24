//
//  Configuration.swift
//  DistributedCalculator
//
//  Created by Илья Халяпин on 23.02.2018.
//  Copyright © 2018 Ilia Khaliapin. All rights reserved.
//

import Foundation

/// Конфигурация
final class Configuration: Decodable {
    
    // MARK: - Публичные свойства
    
    /// Входящее число
    var enteringNumber: Double
    /// Параметры
    var parameters: [Parameter]
    
    
    // MARK: - Инициализация
    
    init?(data: Data) {
        guard let string = String(data: data, encoding: .ascii) else { return nil }
        
        print("Data -> Configuration [length: \(string.count)]")
        print(string)
        
        let endLine = "\r\n"
        var items = string.components(separatedBy: endLine).filter { !$0.isEmpty }
        
        guard !items.isEmpty else { return nil }
        
        guard let enteringNumber = Double(items.removeFirst()) else { return nil }
        self.enteringNumber = enteringNumber
        
        let parameters: [Parameter] = items.flatMap { item in
            let components = item.components(separatedBy: " ").filter { !$0.isEmpty }
            guard components.count == 2, let value = Double(components[1]) else { return nil }
            
            let parameter = Parameter(action: components[0], value: value)
            return parameter
        }
        guard !parameters.isEmpty else { return nil }
        
        self.parameters = parameters
    }
    
}


// MARK: - Публичные свойства

extension Configuration {
    
    var data: Data? {
        var items = self.parameters.map { "\($0.action) \($0.value)" }
        items.insert("\(self.enteringNumber)", at: 0)
        
        let endLine = "\r\n"
        let string = items.map { $0 + endLine }.reduce("") { $0 + $1 }
        
        print("Configuration -> Data [length: \(string.count)]")
        print(string)
        
        let data = string.data(using: .ascii)
        return data
    }
    
}
