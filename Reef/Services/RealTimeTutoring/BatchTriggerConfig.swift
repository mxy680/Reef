//
//  BatchTriggerConfig.swift
//  Reef
//
//  Configurable thresholds for the interval-based batch trigger.
//

import Foundation

/// Configuration for the interval-based batch trigger.
struct BatchTriggerConfig {
    /// Minimum interval between screenshot sends (seconds)
    var interval: TimeInterval = 2.0

    /// How often to check trigger conditions (seconds)
    var checkInterval: TimeInterval = 0.1

    static let `default` = BatchTriggerConfig()
}
