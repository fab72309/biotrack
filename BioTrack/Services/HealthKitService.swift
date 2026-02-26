import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

enum HealthAuthorizationState: String {
    case notAvailable
    case notDetermined
    case denied
    case authorized
}

final class HealthKitService {
    static let shared = HealthKitService()
    private init() {}

    private let defaults = AppGroup.sharedDefaults()
    private let requestedKey = "healthkit.authorization.requested"
    private let grantedKey = "healthkit.authorization.granted"
    
    #if canImport(HealthKit)
    let store = HKHealthStore()
    #endif
    
    func isAvailable() -> Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }
    
    func authorizationState() -> HealthAuthorizationState {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return .notAvailable }
        if defaults.bool(forKey: grantedKey) {
            return .authorized
        }

        let representative = store.authorizationStatus(for: representativeReadType())
        if representative == .sharingAuthorized {
            defaults.set(true, forKey: grantedKey)
            return .authorized
        }
        if representative == .sharingDenied {
            return .denied
        }
        if defaults.bool(forKey: requestedKey) {
            return .denied
        }
        return .notDetermined
        #else
        return .notAvailable
        #endif
    }
    
    func requestAuthorization() async -> Bool {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        defaults.set(true, forKey: requestedKey)
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes())
            let granted = await hasReadAccess()
            defaults.set(granted, forKey: grantedKey)
            return granted
        } catch {
            defaults.set(false, forKey: grantedKey)
            return false
        }
        #else
        return false
        #endif
    }
    
    func fetchDailySteps(start: Date, end: Date) async throws -> [Date: Double] {
        #if canImport(HealthKit)
        let type = HKObjectType.quantityType(forIdentifier: .stepCount)!
        return try await fetchDailyStatistics(quantityType: type,
                                             start: start,
                                             end: end,
                                             options: .cumulativeSum,
                                             unit: .count())
        #else
        return [:]
        #endif
    }
    
    func fetchDailyBodyMass(start: Date, end: Date) async throws -> [Date: Double] {
        #if canImport(HealthKit)
        let type = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        return try await fetchDailyStatistics(quantityType: type,
                                             start: start,
                                             end: end,
                                             options: .mostRecent,
                                             unit: .gramUnit(with: .kilo))
        #else
        return [:]
        #endif
    }
    
    func fetchDailyRestingHeartRate(start: Date, end: Date) async throws -> [Date: Double] {
        #if canImport(HealthKit)
        let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        let unit = HKUnit.count().unitDivided(by: .minute())
        return try await fetchDailyStatistics(quantityType: type,
                                             start: start,
                                             end: end,
                                             options: .discreteAverage,
                                             unit: unit)
        #else
        return [:]
        #endif
    }
    
    func fetchDailyHRV(start: Date, end: Date) async throws -> [Date: Double] {
        #if canImport(HealthKit)
        let type = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let unit = HKUnit.secondUnit(with: .milli)
        return try await fetchDailyStatistics(quantityType: type,
                                             start: start,
                                             end: end,
                                             options: .discreteAverage,
                                             unit: unit)
        #else
        return [:]
        #endif
    }
    
    func fetchSleepDurations(start: Date, end: Date) async throws -> [Date: Double] {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return [:] }
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType,
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: sort) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                var out: [Date: Double] = [:]
                let cal = Calendar.current
                var asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleep.rawValue
                ]
                if #available(iOS 16.0, *) {
                    asleepValues.formUnion([
                        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    ])
                }
                
                for case let sample as HKCategorySample in samples ?? [] {
                    guard asleepValues.contains(sample.value) else { continue }
                    let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                    let day = cal.startOfDay(for: sample.endDate)
                    out[day, default: 0] += minutes
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }
        #else
        return [:]
        #endif
    }

    func isAuthorizationError(_ error: Error) -> Bool {
        #if canImport(HealthKit)
        guard let hkError = error as? HKError else { return false }
        return hkError.code == .errorAuthorizationDenied || hkError.code == .errorAuthorizationNotDetermined
        #else
        return false
        #endif
    }
    
    // MARK: - Private
    #if canImport(HealthKit)
    private func readTypes() -> Set<HKObjectType> {
        return [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ]
    }

    private func representativeReadType() -> HKObjectType {
        HKObjectType.quantityType(forIdentifier: .stepCount)!
    }

    private func hasReadAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            let type = HKObjectType.quantityType(forIdentifier: .stepCount)!
            let start = Calendar.current.date(byAdding: .day, value: -7, to: Date())
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
            let query = HKSampleQuery(sampleType: type,
                                      predicate: predicate,
                                      limit: 1,
                                      sortDescriptors: nil) { _, _, error in
                if let error = error {
                    continuation.resume(returning: !self.isAuthorizationError(error))
                } else {
                    continuation.resume(returning: true)
                }
            }
            store.execute(query)
        }
    }
    
    private func fetchDailyStatistics(quantityType: HKQuantityType,
                                      start: Date,
                                      end: Date,
                                      options: HKStatisticsOptions,
                                      unit: HKUnit) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: start)
        let interval = DateComponents(day: 1)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                    quantitySamplePredicate: predicate,
                                                    options: options,
                                                    anchorDate: anchor,
                                                    intervalComponents: interval)
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                var out: [Date: Double] = [:]
                if let results = results {
                    results.enumerateStatistics(from: start, to: end) { stats, _ in
                        let day = cal.startOfDay(for: stats.startDate)
                        let quantity: HKQuantity?
                        if options.contains(.cumulativeSum) {
                            quantity = stats.sumQuantity()
                        } else if options.contains(.mostRecent) {
                            quantity = stats.mostRecentQuantity()
                        } else if options.contains(.discreteAverage) {
                            quantity = stats.averageQuantity()
                        } else {
                            quantity = stats.sumQuantity()
                        }
                        if let quantity = quantity {
                            out[day] = quantity.doubleValue(for: unit)
                        }
                    }
                }
                continuation.resume(returning: out)
            }
            store.execute(query)
        }
    }
    #endif
}
