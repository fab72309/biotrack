import SwiftUI

struct ChartPoint {
	let date: Date
	let displayValue: Double
	let rawValue: Double
}

struct ChartSeries: Identifiable {
	let id: String
	let name: String
	let color: Color
	let styleIndex: Int
	let points: [ChartPoint]
	let rawUnit: String
	let rawValueFormatter: ((Double) -> String)?
}

struct MultiSeriesChart: View {
	enum YAxisMode {
		case durationMinutes
		case numeric
	}

	let series: [ChartSeries]
	let style: StatsView.ChartStyle
	let unit: String
	let yAxisMode: YAxisMode
	let ticks: [Date]?
	let yMinForced: Double?
	let yMaxForced: Double?
	let valueFormatter: ((Double) -> String)?
	let avgLineValue: Double?
	let showLegend: Bool

	private struct HoverSelection {
		let point: CGPoint
		let text: String
	}

	@State private var hover: HoverSelection? = nil

	var body: some View {
		GeometryReader { geo in
			let rect = geo.frame(in: .local)
			ZStack {
				axes(in: rect)
				Group {
						if style == .line {
							ForEach(series) { s in
								if series.count == 1 { areaPath(s, in: rect).fill(s.color.opacity(0.12)) }
								linePath(s, in: rect)
									.stroke(
										s.color,
										style: StrokeStyle(
											lineWidth: 2.5,
											lineCap: .round,
											lineJoin: .round,
											dash: dashPattern(for: s.styleIndex)
										)
									)
								let pts = normalizedPoints(s.points, in: rect)
								ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
									pointSymbol(styleIndex: s.styleIndex, color: s.color)
										.frame(width: 7, height: 7)
										.position(p)
								}
							}
					} else {
						bars(in: rect)
					}
					if let avg = avgLineValue { averageLine(at: avg, in: rect) }
				}
					.mask(plotMask(in: rect))
					if showLegend { legend(in: rect) }
					if let hover = hover {
						crosshair(at: hover.point, in: rect)
						tooltip(at: hover.point, text: hover.text, in: rect)
					}
			}
			.contentShape(Rectangle())
				.gesture(DragGesture(minimumDistance: 0)
					.onChanged { value in updateHover(at: value.location, in: rect) }
					.onEnded { _ in hover = nil }
				)
				.accessibilityElement(children: .ignore)
				.accessibilityLabel("Graphique \(series.map(\.name).joined(separator: ", "))")
				.accessibilityValue(accessibilitySummary)
				.accessibilityHint("Touchez et faites glisser pour explorer les valeurs.")
			}
		}

	private let leftPadding: CGFloat = 56
	private let rightPadding: CGFloat = 20 // garde pour éviter chevauchement
	private let topPadding: CGFloat = 10
	private let bottomPadding: CGFloat = 48

	private func plotMask(in r: CGRect) -> some View {
		Path { p in
			p.addRect(CGRect(x: leftPadding, y: topPadding, width: r.width - leftPadding - rightPadding, height: r.height - topPadding - bottomPadding))
		}.fill(Color.black)
	}

	private func axes(in r: CGRect) -> some View {
		return ZStack(alignment: .topLeading) {
			Path { p in
				p.move(to: CGPoint(x: leftPadding, y: topPadding))
				p.addLine(to: CGPoint(x: leftPadding, y: r.height-bottomPadding))
				p.addLine(to: CGPoint(x: r.width-rightPadding, y: r.height-bottomPadding))
			}.stroke(Color.secondary.opacity(0.5), lineWidth: 1)
			let yTickValues = makeNiceYTicks()
			ForEach(yTickValues, id: \.self) { v in
				let y = yPosition(for: v, in: r)
				Path { p in
					p.move(to: CGPoint(x: leftPadding, y: y))
					p.addLine(to: CGPoint(x: r.width-rightPadding, y: y))
				}
				.stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 0.5, dash: [4,3]))
			}
				ForEach(yTickValues, id: \.self) { v in
					Text(labelY(v))
						.font(.system(size: 10))
						.foregroundColor(.secondary)
						.lineLimit(1)
						.minimumScaleFactor(0.75)
						.frame(width: leftPadding - 10, alignment: .trailing)
						.position(x: (leftPadding - 10) / 2, y: yPosition(for: v, in: r) - 6)
				}
				// Unité Y centrée verticalement, à gauche de l’axe
				Text(unit)
					.font(.system(size: 10))
					.foregroundColor(.secondary)
					.rotationEffect(.degrees(-90))
					.position(x: 10, y: (topPadding + (r.height-bottomPadding)) / 2)
			let tickDates = ticks ?? defaultTicks()
			if let first = tickDates.first, let last = tickDates.last {
				ForEach(tickDates, id: \.self) { d in
					let x = xPosition(for: d, first: first, last: last, width: r.width)
					Path { p in
						p.move(to: CGPoint(x: x, y: topPadding))
						p.addLine(to: CGPoint(x: x, y: r.height-bottomPadding))
					}
					.stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 0.5, dash: [4,3]))
				}
				ForEach(tickDates, id: \.self) { d in
					let x = xPosition(for: d, first: first, last: last, width: r.width)
					Text(shortDate(d))
						.font(.system(size: 10))
						.foregroundColor(.secondary)
						.lineLimit(1)
						.fixedSize(horizontal: true, vertical: false)
						.position(x: x, y: r.height - bottomPadding + 10)
				}
			}
		}
	}

	private func linePath(_ s: ChartSeries, in r: CGRect) -> Path {
		var path = Path()
		let pts = normalizedPoints(s.points, in: r)
		guard let first = pts.first else { return path }
		path.move(to: first)
		for p in pts.dropFirst() { path.addLine(to: p) }
		return path
	}

	private func areaPath(_ s: ChartSeries, in r: CGRect) -> Path {
		var path = Path()
		let pts = normalizedPoints(s.points, in: r)
		guard let first = pts.first else { return path }
		path.move(to: CGPoint(x: first.x, y: r.height-bottomPadding))
		path.addLine(to: first)
		for p in pts.dropFirst() { path.addLine(to: p) }
		if let last = pts.last { path.addLine(to: CGPoint(x: last.x, y: r.height-bottomPadding)) }
		path.closeSubpath()
		return path
	}

	private func bars(in r: CGRect) -> some View {
		let all = series.flatMap { $0.points }
		let uniqueDates = Array(Set(all.map { $0.date })).sorted()
		var slotWidth = (r.width - leftPadding - rightPadding) / CGFloat(max(uniqueDates.count, 1))
		if let t = ticks, let first = t.first, let last = t.last {
			let cal = Calendar.current
			let days = max(1, Int((cal.startOfDay(for: last).timeIntervalSince1970 - cal.startOfDay(for: first).timeIntervalSince1970) / 86400))
			slotWidth = (r.width - leftPadding - rightPadding) / CGFloat(days)
		} else if let (d0, d1) = dateRange() {
			let cal = Calendar.current
			let days = max(1, Int((cal.startOfDay(for: d1).timeIntervalSince1970 - cal.startOfDay(for: d0).timeIntervalSince1970) / 86400))
			slotWidth = (r.width - leftPadding - rightPadding) / CGFloat(days)
		}
		let groupWidth = max(8, slotWidth * 0.7)
		let barWidth = max(4, min(22, groupWidth / CGFloat(max(series.count, 1))))
		let baseY = r.height - bottomPadding
		return ZStack {
			ForEach(Array(series.enumerated()), id: \.element.id) { (idx, s) in
				let pts = normalizedPoints(s.points, in: r)
				ForEach(Array(pts.enumerated()), id: \.0) { (_, p) in
					Path { path in
						let total = barWidth * CGFloat(series.count)
						let xLeft = p.x - total/2 + CGFloat(idx) * barWidth
						let rawH = baseY - p.y
						let minH: CGFloat = 2
						let height = max(minH, rawH)
						let yTop = rawH < minH ? baseY - minH : p.y
						path.addRect(CGRect(x: xLeft, y: yTop, width: barWidth-2, height: height))
					}
					.fill(s.color.opacity(0.85))
					.overlay(
						Path { path in
							let total = barWidth * CGFloat(series.count)
							let xLeft = p.x - total/2 + CGFloat(idx) * barWidth
							let rawH = baseY - p.y
							let minH: CGFloat = 2
							let height = max(minH, rawH)
							let yTop = rawH < minH ? baseY - minH : p.y
							path.addRect(CGRect(x: xLeft, y: yTop, width: barWidth-2, height: height))
						}
						.stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
					)
				}
			}
		}
	}

	private func normalizedPoints(_ points: [ChartPoint], in r: CGRect) -> [CGPoint] {
		let sorted = points.sorted { $0.date < $1.date }
		guard let fallbackFirst = sorted.first?.date, let fallbackLast = sorted.last?.date else { return [] }
		let cal = Calendar.current
		let range: (Date, Date)
		if let t = ticks, let first = t.first, let last = t.last { range = (first, last) }
		else if let d = dateRange() { range = d } else { range = (fallbackFirst, fallbackLast) }
		let firstDay = cal.startOfDay(for: range.0)
		let lastEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: range.1)) ?? range.1
		let total = max(lastEnd.timeIntervalSince1970 - firstDay.timeIntervalSince1970, 1)
		let (minV, maxV) = yRange()
		let plotWidth = r.width - leftPadding - rightPadding
		return sorted.map { point in
			let clampedDate = min(max(point.date, firstDay), lastEnd)
			let x = leftPadding + CGFloat((clampedDate.timeIntervalSince1970 - firstDay.timeIntervalSince1970)/total) * plotWidth
			let norm = (point.displayValue - minV) / max(maxV - minV, 1e-6)
			let y = (r.height-bottomPadding) - CGFloat(norm) * (r.height-bottomPadding-topPadding)
			return CGPoint(x: x, y: y)
		}
	}

	private func yRange() -> (Double, Double) {
		let allVals = series.flatMap { $0.points.map(\.displayValue) }
		let rawMin = allVals.min() ?? 0
		let rawMax = allVals.max() ?? 1
		// marge de 10% et garde-fous si min == max
		var minV = rawMin
		var maxV = rawMax
		if maxV - minV < 1e-6 {
			// valeurs quasi constantes: ajoute une petite fenêtre autour
			minV = rawMin - abs(rawMin)*0.1 - 1
			maxV = rawMax + abs(rawMax)*0.1 + 1
		} else {
			let padding = (maxV - minV) * 0.1
			minV -= padding
			maxV += padding
		}
		if let forcedMinimum = yMinForced { minV = forcedMinimum }
		if let forcedMaximum = yMaxForced { maxV = forcedMaximum }
		// éviter NaN et bornes inversées
		if minV.isNaN || maxV.isNaN || !minV.isFinite || !maxV.isFinite || maxV <= minV { return (0, 1) }
		return (minV, maxV)
	}

	private func labelY(_ v: Double) -> String {
		if let f = valueFormatter { return f(v) }
		if yAxisMode == .durationMinutes {
			let mins = max(0, Int(round(v)))
			let h = mins/60
			let mm = mins%60
			return String(format: "%dh%02d", h, mm)
		}
		return abs(v) >= 100 ? String(Int(v.rounded())) : String(format: "%.0f", v)
	}

	private func averageLine(at value: Double, in r: CGRect) -> some View {
		let (minV, maxV) = yRange()
		let norm = (value - minV) / max(maxV - minV, 1e-6)
		let y = (r.height-bottomPadding) - CGFloat(norm) * (r.height-bottomPadding-topPadding)
		return ZStack(alignment: .topLeading) {
			Path { p in
				p.move(to: CGPoint(x: leftPadding, y: y))
				p.addLine(to: CGPoint(x: r.width-rightPadding, y: y))
			}
			.stroke(Color.orange.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [5,3]))
			Text("Moyenne")
				.font(.caption2)
				.foregroundColor(.orange)
				.background(Color(UIColor.systemBackground).opacity(0.6))
				.position(x: r.width-60, y: max(12, y-10))
		}
	}

	private func dateRange() -> (Date, Date)? {
		let all = series.flatMap { $0.points }
		guard let minD = all.map(\.date).min(), let maxD = all.map(\.date).max() else { return nil }
		return (minD, maxD)
	}

	private func shortDate(_ d: Date) -> String {
		let f = DateFormatter()
		f.dateFormat = "dd/MM"
		return f.string(from: d)
	}

	private func defaultTicks() -> [Date] {
		if let (d0, d1) = dateRange() {
			let cal = Calendar.current
			let days = Int((cal.startOfDay(for: d1).timeIntervalSince1970 - cal.startOfDay(for: d0).timeIntervalSince1970) / 86400.0)
			let step = max(1, days / 4)
			var arr: [Date] = []
			var d = cal.startOfDay(for: d0)
			while d <= d1 { arr.append(d); d = cal.date(byAdding: .day, value: step, to: d)! }
			arr.append(cal.startOfDay(for: d1))
			return Array(Set(arr)).sorted()
		}
		return []
	}

	private func xPosition(for d: Date, first: Date, last: Date, width: CGFloat) -> CGFloat {
		let cal = Calendar.current
		let firstDay = cal.startOfDay(for: first)
		let lastEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: last)) ?? last
		let total = max(lastEnd.timeIntervalSince1970 - firstDay.timeIntervalSince1970, 1)
		let plotWidth = width - leftPadding - rightPadding
		let clamped = min(max(d, firstDay), lastEnd)
		return leftPadding + CGFloat((clamped.timeIntervalSince1970 - firstDay.timeIntervalSince1970)/total) * plotWidth
	}

	private func updateHover(at location: CGPoint, in r: CGRect) {
		// Build all normalized points with metadata
		var candidates: [(CGPoint, String, CGFloat)] = []
		let f = DateFormatter(); f.dateStyle = .medium
		for s in series {
			let sorted = s.points.sorted { $0.date < $1.date }
			let pts = normalizedPoints(sorted, in: r)
			for (i, p) in pts.enumerated() where i < sorted.count {
				let point = sorted[i]
				let rawValue = point.rawValue
				let valueText = s.rawValueFormatter?(rawValue) ?? (rawValue >= 100 ? String(Int(rawValue)) : String(format: "%.0f", rawValue))
				let unitSuffix = s.rawUnit.isEmpty ? "" : " \(s.rawUnit)"
				let text = "\(s.name)\n\(f.string(from: point.date)) • \(valueText)\(unitSuffix)"
				let dist = hypot(location.x - p.x, location.y - p.y)
				candidates.append((p, text, dist))
			}
		}
		if let nearest = candidates.min(by: { $0.2 < $1.2 }), nearest.2 < 44 {
			hover = HoverSelection(point: nearest.0, text: nearest.1)
		} else {
			hover = nil
		}
	}

	private func tooltip(at point: CGPoint, text: String, in rect: CGRect) -> some View {
		let tooltipWidth = min(max(rect.width - 32, 160), 250)
		let x = min(max(point.x, tooltipWidth / 2 + 8), rect.width - tooltipWidth / 2 - 8)
		let y = point.y < 82 ? min(rect.height - bottomPadding - 42, point.y + 54) : point.y - 44
		return VStack(spacing: 4) {
			Text(text)
				.font(.caption.weight(.medium))
				.multilineTextAlignment(.center)
				.padding(8)
				.frame(maxWidth: tooltipWidth)
				.background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground)))
				.overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.35), lineWidth: 0.5))
				.shadow(color: .black.opacity(0.12), radius: 8, y: 3)
		}
		.position(x: x, y: y)
	}

	private func legend(in r: CGRect) -> some View {
		HStack(spacing: 12) {
			ForEach(series) { s in
				HStack(spacing: 6) {
					pointSymbol(styleIndex: s.styleIndex, color: s.color)
						.frame(width: 8, height: 8)
					Text(s.name).font(.caption2)
				}
			}
			Spacer()
		}
		.padding(.top, r.height-22)
	}

	private func yPosition(for value: Double, in r: CGRect) -> CGFloat {
		let (minV, maxV) = yRange()
		let norm = (value - minV) / max(maxV - minV, 1e-6)
		return (r.height-bottomPadding) - CGFloat(norm) * (r.height-bottomPadding-topPadding)
	}

	private func makeNiceYTicks() -> [Double] {
		let (minV, maxV) = yRange()
		guard minV.isFinite, maxV.isFinite else { return [0, 1] }
		guard maxV > minV else { return [minV] }
		switch yAxisMode {
		case .durationMinutes:
			return durationTicks(minValue: minV, maxValue: maxV)
		case .numeric:
			return numericTicks(minValue: minV, maxValue: maxV)
		}
	}

	private func durationTicks(minValue: Double, maxValue: Double) -> [Double] {
		let allowedSteps: [Double] = [15, 30, 60, 120, 180, 240]
		var selectedStep = allowedSteps[0]
		var bestScore = Double.greatestFiniteMagnitude

		for step in allowedSteps {
			let lower = floor(minValue / step) * step
			let upper = ceil(maxValue / step) * step
			let count = max(2, Int(round((upper - lower) / step)) + 1)
			let overloadPenalty = count < 4 ? Double((4 - count) * 3) : (count > 7 ? Double(count - 7) : 0)
			let score = overloadPenalty * 100 + abs(Double(count) - 5)
			if score < bestScore {
				bestScore = score
				selectedStep = step
			}
		}

		let lower = floor(minValue / selectedStep) * selectedStep
		let upper = ceil(maxValue / selectedStep) * selectedStep
		return constrainedTicks(from: lower, to: upper, step: selectedStep)
	}

	private func numericTicks(minValue: Double, maxValue: Double) -> [Double] {
		let span = maxValue - minValue
		guard span > 0 else { return [minValue] }

		var step = niceNumber(span / 4.0, round: true)
		var lower = floor(minValue / step) * step
		var upper = ceil(maxValue / step) * step
		var ticks = constrainedTicks(from: lower, to: upper, step: step)
		var guardCount = 0

		while ticks.count > 7 && guardCount < 8 {
			step = niceNumber(step * 1.6, round: false)
			lower = floor(minValue / step) * step
			upper = ceil(maxValue / step) * step
			ticks = constrainedTicks(from: lower, to: upper, step: step)
			guardCount += 1
		}

		return ticks
	}

	private func constrainedTicks(from lower: Double, to upper: Double, step: Double) -> [Double] {
		guard step > 0, upper.isFinite, lower.isFinite else { return [lower, upper] }
		var ticks: [Double] = []
		var current = lower
		var safety = 0
		while current <= upper + (step * 0.5), safety < 256 {
			ticks.append(roundTick(current))
			current += step
			safety += 1
		}
		if ticks.isEmpty { ticks = [roundTick(lower), roundTick(upper)] }
		ticks = deduplicatedTicks(ticks)

		if ticks.count > 7 {
			let stride = Int(ceil(Double(ticks.count - 1) / Double(7 - 1)))
			var reduced = ticks.enumerated().compactMap { index, value in
				index % max(stride, 1) == 0 ? value : nil
			}
			if let last = ticks.last, reduced.last != last {
				reduced.append(last)
			}
			ticks = deduplicatedTicks(reduced)
		}

		return ticks
	}

	private func deduplicatedTicks(_ ticks: [Double]) -> [Double] {
		var seen: Set<String> = []
		var out: [Double] = []
		for tick in ticks.sorted() {
			let key = String(format: "%.6f", tick)
			if !seen.contains(key) {
				seen.insert(key)
				out.append(tick)
			}
		}
		return out
	}

	private func roundTick(_ value: Double) -> Double {
		let rounded = (value * 1_000_000).rounded() / 1_000_000
		return rounded == -0 ? 0 : rounded
	}

	private func niceNumber(_ value: Double, round: Bool) -> Double {
		guard value.isFinite, value > 0 else { return 1 }
		let exponent = floor(log10(value))
		let fraction = value / pow(10, exponent)
		let niceFraction: Double
		if round {
			if fraction < 1.5 { niceFraction = 1 }
			else if fraction < 2.25 { niceFraction = 2 }
			else if fraction < 3.75 { niceFraction = 2.5 }
			else if fraction < 7.5 { niceFraction = 5 }
			else { niceFraction = 10 }
		} else {
			if fraction <= 1 { niceFraction = 1 }
			else if fraction <= 2 { niceFraction = 2 }
			else if fraction <= 2.5 { niceFraction = 2.5 }
			else if fraction <= 5 { niceFraction = 5 }
			else { niceFraction = 10 }
		}
		return niceFraction * pow(10, exponent)
	}

	private func dashPattern(for styleIndex: Int) -> [CGFloat] {
		switch styleIndex % 3 {
		case 1: return [8, 4]
		case 2: return [2, 3]
		default: return []
		}
	}

	@ViewBuilder
	private func pointSymbol(styleIndex: Int, color: Color) -> some View {
		switch styleIndex % 3 {
		case 1:
			RoundedRectangle(cornerRadius: 1.5, style: .continuous)
				.fill(color)
		case 2:
			Diamond()
				.fill(color)
		default:
			Circle()
				.fill(color)
		}
	}

	private func crosshair(at point: CGPoint, in rect: CGRect) -> some View {
		Path { path in
			path.move(to: CGPoint(x: point.x, y: topPadding))
			path.addLine(to: CGPoint(x: point.x, y: rect.height - bottomPadding))
		}
		.stroke(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
	}

	private var accessibilitySummary: String {
		let summaries = series.compactMap { item -> String? in
			let sorted = item.points.sorted { $0.date < $1.date }
			guard let first = sorted.first, let last = sorted.last else { return nil }
			let firstValue = item.rawValueFormatter?(first.rawValue) ?? String(format: "%.1f", first.rawValue)
			let lastValue = item.rawValueFormatter?(last.rawValue) ?? String(format: "%.1f", last.rawValue)
			let direction: String
			if last.displayValue > first.displayValue {
				direction = "en hausse"
			} else if last.displayValue < first.displayValue {
				direction = "en baisse"
			} else {
				direction = "stable"
			}
			let unitSuffix = item.rawUnit.isEmpty ? "" : " \(item.rawUnit)"
			return "\(item.name), \(direction), de \(firstValue)\(unitSuffix) à \(lastValue)\(unitSuffix)"
		}
		return summaries.isEmpty ? "Aucune donnée sur la période." : summaries.joined(separator: ". ")
	}
}

private struct Diamond: Shape {
	func path(in rect: CGRect) -> Path {
		var path = Path()
		path.move(to: CGPoint(x: rect.midX, y: rect.minY))
		path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
		path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
		path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
		path.closeSubpath()
		return path
	}
}
