import Foundation

enum ExportService {
    static func csvMetrics(metrics: [Metric], entries: [MetricEntry]) -> String {
        var lines = ["metric_id,metric_name,date,value"]
        let fmt = ISO8601DateFormatter()
        for e in entries {
            let name = metrics.first(where: { $0.id == e.metricId })?.name ?? ""
            lines.append("\(e.metricId.uuidString),\(name),\(fmt.string(from: e.date)),\(e.value)")
        }
        return lines.joined(separator: "\n")
    }
}
