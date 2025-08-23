import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

final class HealthKitService {
    static let shared = HealthKitService()
    private init() {}
    
    #if canImport(HealthKit)
    let store = HKHealthStore()
    #endif
    
    func requestAuthorization() async -> Bool {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        
        let readTypes: Set = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        let writeTypes: Set = [
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        ]
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
}
