//
//  Parameter.swift
//  DitributedCalculator
//
//  Created by Илья Халяпин on 23.02.2018.
//  Copyright © 2018 Ilia Khaliapin. All rights reserved.
//

/// Параметр конфигурации
final class Parameter: Decodable {
    
    // MARK: - Публичные свойства
    
    /// Действие
    let action: String
    /// Значение
    let value: Double
    
    
    // MARK: - Инициализация
    
    init(action: String, value: Double) {
        self.action = action
        self.value = value
    }
    
}
