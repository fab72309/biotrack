import SwiftUI

struct ChartSeries: Identifiable {
	let id = UUID()
	let name: String
	let color: Color
	let points: [(Date, Double)]
}

struct MultiSeriesChart: View {
	let series: [ChartSeries]
	let style: StatsView.ChartStyle
	let unit: String
	let ticks: [Date]?
	let yMinForced: Double?
	let yMaxForced: Double?
	let valueFormatter: ((Double) -> String)?
	let avgLineValue: Double?
	let showLegend: Bool

	@State private var hover: (CGPoint, String)? = nil

	var body: some View {
		GeometryReader { geo in
			let rect = geo.frame(in: .local)
			ZStack {
				axes(in: rect)
				Group {
					if style == .line {
						ForEach(series) { s in
							if series.count == 1 { areaPath(s, in: rect).fill(s.color.opacity(0.12)) }
							splineLinePath(s, in: rect).stroke(s.color, lineWidth: 2)
							let pts = normalizedPoints(s.points, in: rect)
							ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
								Circle().fill(s.color).frame(width: 4, height: 4).position(p)
							}
						}
					} else {
						bars(in: rect)
					}
					if let avg = avgLineValue { averageLine(at: avg, in: rect) }
				}
				.mask(plotMask(in: rect))
				if showLegend { legend(in: rect) }
				if let hover = hover { tooltip(at: hover.0, text: hover.1) }
			}
			.contentShape(Rectangle())
			.gesture(DragGesture(minimumDistance: 0)
				.onChanged { value in updateHover(at: value.location, in: rect) }
				.onEnded { _ in hover = nil }
			)
		}
	}

	private let leftPadding: CGFloat = 40
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
					.fixedSize(horizontal: true, vertical: false)
					.position(x: leftPadding-24, y: yPosition(for: v, in: r) - 6)
			}
			// Unité Y centrée verticalement, à gauche de l’axe
			Text(unit)
				.font(.system(size: 10))
				.foregroundColor(.secondary)
				.rotationEffect(.degrees(-90))
				.position(x: leftPadding-40, y: (topPadding + (r.height-bottomPadding)) / 2)
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

	private func splineLinePath(_ s: ChartSeries, in r: CGRect) -> Path {
		var path = Path()
		let pts = normalizedPoints(s.points, in: r)
		guard pts.count > 0 else { return path }
		if pts.count < 3 { return linePath(s, in: r) }
		path.move(to: pts[0])
		let tension: CGFloat = 0.5 // 0..1 (plus grand = plus lisse)
		for i in 0..<(pts.count - 1) {
			let p0 = i == 0 ? pts[i] : pts[i - 1]
			let p1 = pts[i]
			let p2 = pts[i + 1]
			let p3 = (i + 2 < pts.count) ? pts[i + 2] : pts[i + 1]
			let d1 = CGPoint(x: (p2.x - p0.x) * (tension / 6.0), y: (p2.y - p0.y) * (tension / 6.0))
			let d2 = CGPoint(x: (p3.x - p1.x) * (tension / 6.0), y: (p3.y - p1.y) * (tension / 6.0))
			let cp1 = CGPoint(x: p1.x + d1.x, y: p1.y + d1.y)
			let cp2 = CGPoint(x: p2.x - d2.x, y: p2.y - d2.y)
			path.addCurve(to: p2, control1: cp1, control2: cp2)
		}
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
		let uniqueDates = Array(Set(all.map { $0.0 })).sorted()
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

	private func normalizedPoints(_ points: [(Date, Double)], in r: CGRect) -> [CGPoint] {
		let sorted = points.sorted { $0.0 < $1.0 }
		guard let fallbackFirst = sorted.first?.0, let fallbackLast = sorted.last?.0 else { return [] }
		let cal = Calendar.current
		let range: (Date, Date)
		if let t = ticks, let first = t.first, let last = t.last { range = (first, last) }
		else if let d = dateRange() { range = d } else { range = (fallbackFirst, fallbackLast) }
		let firstDay = cal.startOfDay(for: range.0)
		let lastEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: range.1))! // fin de journée incluse
		let total = lastEnd.timeIntervalSince1970 - firstDay.timeIntervalSince1970
		let (minV, maxV) = yRange()
		let plotWidth = r.width - leftPadding - rightPadding
		return sorted.map { (d, v) in
			let clampedDate = min(max(d, firstDay), lastEnd)
			let x = leftPadding + CGFloat((clampedDate.timeIntervalSince1970 - firstDay.timeIntervalSince1970)/total) * plotWidth
			let norm = (v - minV) / max(maxV - minV, 1e-6)
			let y = (r.height-bottomPadding) - CGFloat(norm) * (r.height-bottomPadding-topPadding)
			return CGPoint(x: x, y: y)
		}
	}

	private func yRange() -> (Double, Double) {
		if let minF = yMinForced, let maxF = yMaxForced { return (minF, maxF) }
		let allVals = series.flatMap { $0.points.map { $0.1 } }
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
		// éviter NaN et bornes inversées
		if minV.isNaN || maxV.isNaN || !minV.isFinite || !maxV.isFinite { return (0, 1) }
		return (minV, maxV)
	}

	private func labelY(_ v: Double) -> String {
		if let f = valueFormatter { return f(v) }
		let safe = max(0, v)
		if unit.lowercased().contains("h") {
			let mins = max(0, Int(round(safe)))
			let h = mins/60
			let mm = mins%60
			return String(format: "%dh%02d", h, mm)
		}
		return safe >= 100 ? String(Int(safe)) : String(format: "%.0f", safe)
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
		guard let minD = all.map({ $0.0 }).min(), let maxD = all.map({ $0.0 }).max() else { return nil }
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
		let lastEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: last))!
		let total = lastEnd.timeIntervalSince1970 - firstDay.timeIntervalSince1970
		let plotWidth = width - leftPadding - rightPadding
		let clamped = min(max(d, firstDay), lastEnd)
		return leftPadding + CGFloat((clamped.timeIntervalSince1970 - firstDay.timeIntervalSince1970)/total) * plotWidth
	}

	private func updateHover(at location: CGPoint, in r: CGRect) {
		// Build all normalized points with metadata
		var candidates: [(CGPoint, String, CGFloat)] = []
		let f = DateFormatter(); f.dateStyle = .medium
		for s in series {
			let pts = normalizedPoints(s.points, in: r)
			let sorted = s.points.sorted { $0.0 < $1.0 }
			for (i, p) in pts.enumerated() where i < sorted.count {
				let (date, val) = sorted[i]
				let valueText = valueFormatter?(val) ?? (val >= 100 ? String(Int(val)) : String(format: "%.0f", val))
				let text = "\(s.name)\n\(f.string(from: date)) • \(valueText) \(unit)"
				let dist = hypot(location.x - p.x, location.y - p.y)
				candidates.append((p, text, dist))
			}
		}
		if let nearest = candidates.min(by: { $0.2 < $1.2 }), nearest.2 < 40 { hover = (nearest.0, nearest.1) } else { hover = nil }
	}

	private func tooltip(at point: CGPoint, text: String) -> some View {
		VStack(spacing: 4) {
			Text(text).font(.caption2).multilineTextAlignment(.center).padding(6).background(RoundedRectangle(cornerRadius: 6).fill(Color(UIColor.systemBackground))).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.4), lineWidth: 0.5))
			Triangle().fill(Color(UIColor.systemBackground)).frame(width: 8, height: 6)
		}
		.position(x: point.x, y: max(20, point.y - 24))
	}

	private func legend(in r: CGRect) -> some View {
		HStack(spacing: 12) {
			ForEach(series) { s in
				HStack(spacing: 6) {
					Circle().fill(s.color).frame(width: 8, height: 8)
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
		let span = maxV - minV
		if span.isNaN || span <= 0 { return [minV, maxV] }
		// Durées: choisir un pas 15/30/60 min qui donne 4..8 ticks
		let isDuration = (unit.lowercased().contains("h") || valueFormatter != nil)
		if isDuration {
			let step: Double = 30 // pas fixe 30 minutes
			var ticks: [Double] = [minV]
			var v = (ceil(minV / step)) * step
			if abs(v - minV) < 1e-6 { v += step }
			while v < maxV - 1e-6 { ticks.append(v); v += step }
			ticks.append(maxV)
			return ticks
		}
		// Valeurs génériques: 6 ticks uniformes
		let count = 6
		return (0..<count).map { i in minV + (Double(i) * span / Double(count - 1)) }
	}
}

private struct Triangle: Shape {
	func path(in rect: CGRect) -> Path {
		var p = Path()
		p.move(to: CGPoint(x: rect.midX, y: rect.minY))
		p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
		p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
		p.closeSubpath()
		return p
	}
}


