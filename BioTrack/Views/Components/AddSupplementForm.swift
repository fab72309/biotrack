import SwiftUI

struct AddSupplementForm: View {
	@Environment(\.dismiss) private var dismiss

	let existing: Supplement?
	let onSave: (Supplement) -> Void

	@State private var name: String
	@State private var brand: String
	@State private var dose: String
	@State private var category: String
	@State private var timeContext: String
	@State private var frequency: Frequency
	@State private var showingCategory = false
	@State private var showingFrequency = false
	@State private var showingTime = false

	init(existing: Supplement? = nil, onSave: @escaping (Supplement) -> Void) {
		self.existing = existing
		self.onSave = onSave
		_name = State(initialValue: existing?.name ?? "")
		_brand = State(initialValue: existing?.brand ?? "")
		_dose = State(initialValue: existing?.dose ?? "")
		_category = State(initialValue: existing?.category ?? "Autre")
		_timeContext = State(initialValue: existing?.timeContext ?? "")
		_frequency = State(initialValue: existing?.frequency ?? .daily)
	}

	var body: some View {
		NavigationView {
			Form {
				Section(header: Text("Général")) {
					TextField("Nom du supplément", text: $name)
					TextField("Marque (optionnel)", text: $brand)
					TextField("Dose (optionnel)", text: $dose)
					Button(action: { showingCategory = true }) {
						HStack {
							Text("Catégorie")
							Spacer()
							Text(category.isEmpty ? "Autre" : category).foregroundColor(.secondary)
							Image(systemName: "chevron.right").foregroundColor(.secondary)
						}
					}
					Button(action: { showingTime = true }) {
						HStack {
							Text("Moment")
							Spacer()
							Text(timeContext.isEmpty ? "Autre" : timeContext).foregroundColor(.secondary)
							Image(systemName: "chevron.right").foregroundColor(.secondary)
						}
					}
					Button(action: { showingFrequency = true }) {
						HStack {
							Text("Fréquence")
							Spacer()
							Text(labelForFrequency(frequency)).foregroundColor(.secondary)
							Image(systemName: "chevron.right").foregroundColor(.secondary)
						}
					}
				}
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .principal) {
					SheetHeader(
						title: existing == nil ? "Nouveau complément" : "Modifier le complément",
						leadingTitle: "Annuler",
						onLeading: { dismiss() },
						trailingTitle: "Enregistrer",
						onTrailing: { save() },
						trailingDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
					)
				}
			}
		}
		.sheet(isPresented: $showingCategory) {
			CategoryPickerSheet(currentSelection: category) { sel in category = sel }
			.withSheetDetentsIfAvailable()
		}
		.sheet(isPresented: $showingFrequency) {
			FrequencyPickerSheet(current: frequency) { f in frequency = f }
			.withSheetDetentsIfAvailable()
		}
		.sheet(isPresented: $showingTime) {
			TimeOfDayPickerSheet(current: timeContext.isEmpty ? "Avec le repas" : timeContext) { s in timeContext = s }
			.withSheetDetentsIfAvailable()
		}
	}

	private func labelForFrequency(_ f: Frequency) -> String {
		switch f {
		case .daily: return "Quotidienne"
		case .timesPerDay(let n): return n <= 1 ? "1 fois/jour" : "\(n) fois/jour"
		case .weekly(let days): return days.isEmpty ? "Si besoin" : "Jours spécifiques"
		}
	}

	private func save() {
		let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedName.isEmpty else { return }
		if var current = existing {
			current.name = trimmedName
			current.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : brand
			current.dose = dose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : dose
			current.category = category
			current.timeContext = timeContext.isEmpty ? nil : timeContext
			current.frequency = frequency
			onSave(current)
		} else {
			let newSupplement = Supplement(
				name: trimmedName,
				brand: brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : brand,
				dose: dose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : dose,
				category: category,
				timeOfDay: nil,
				timeContext: timeContext.isEmpty ? nil : timeContext,
				frequency: frequency,
				timesPerDay: nil,
				daysOfWeek: nil,
				durationNote: nil,
				notes: nil,
				active: true
			)
			onSave(newSupplement)
		}
		dismiss()
	}
}

