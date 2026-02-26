import Foundation

struct ExperimentWizardInput {
    let title: String
    let hypothesis: String
    let targetMetricId: UUID
    let startDate: Date
    let durationDays: Int
    let phaseDurationDays: Int
    let controlLabel: String
    let interventionLabel: String
}

struct ExperimentSummary {
    let controlAverage: Double?
    let interventionAverage: Double?
    let delta: Double?
}

enum ExperimentEngine {
    static func createExperiment(from input: ExperimentWizardInput) -> NOf1Experiment {
        NOf1Experiment(
            title: input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Expérience N-of-1" : input.title,
            hypothesis: input.hypothesis,
            targetMetricId: input.targetMetricId,
            startDate: input.startDate,
            durationDays: max(7, input.durationDays),
            phaseDurationDays: max(3, input.phaseDurationDays),
            status: .active,
            controlLabel: input.controlLabel.isEmpty ? "Contrôle" : input.controlLabel,
            interventionLabel: input.interventionLabel.isEmpty ? "Intervention" : input.interventionLabel
        )
    }

    static func phase(for experiment: NOf1Experiment, on date: Date) -> NOf1Phase {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: experiment.startDate)
        let day = calendar.startOfDay(for: date)
        let elapsed = max(0, calendar.dateComponents([.day], from: start, to: day).day ?? 0)
        let block = max(1, experiment.phaseDurationDays)
        let index = (elapsed / block) % 2
        return index == 0 ? .baselineA : .interventionB
    }

    static func buildSummary(for experiment: NOf1Experiment,
                             observations: [NOf1Observation]) -> ExperimentSummary {
        let data = observations.filter { $0.experimentId == experiment.id }
        let control = data.filter { $0.phase == .baselineA }.map(\.value)
        let intervention = data.filter { $0.phase == .interventionB }.map(\.value)
        let controlAvg = average(control)
        let interventionAvg = average(intervention)
        let delta: Double?
        if let c = controlAvg, let i = interventionAvg {
            delta = i - c
        } else {
            delta = nil
        }
        return ExperimentSummary(controlAverage: controlAvg, interventionAverage: interventionAvg, delta: delta)
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

