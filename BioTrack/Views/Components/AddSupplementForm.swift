import SwiftUI

struct AddSupplementForm: View {
	@Environment(\.dismiss) private var dismiss
	@EnvironmentObject var state: AppState

	let existing: Supplement?
	let onSave: (Supplement, ReminderSheet.ReminderData?) -> Void

	@State private var name: String
	@State private var brand: String
	@State private var dose: String
	@State private var category: String
	@State private var timeContext: String
	@State private var frequency: Frequency
	@State private var active: Bool
	@State private var showingCategory = false
	@State private var showingFrequency = false
	@State private var showingTime = false
	@State private var showingCustomReminder = false
	@State private var showingTemplates = false
	@State private var customReminderData: ReminderSheet.ReminderData? = nil
	@State private var didSelectTemplate = false
	@State private var pendingSupplementForCreate: Supplement? = nil
	@State private var pendingReminderForCreate: ReminderSheet.ReminderData? = nil
	@State private var showSaveTemplatePrompt = false

	init(existing: Supplement? = nil, onSave: @escaping (Supplement, ReminderSheet.ReminderData?) -> Void) {
		self.existing = existing
		self.onSave = onSave
		_name = State(initialValue: existing?.name ?? "")
		_brand = State(initialValue: existing?.brand ?? "")
		_dose = State(initialValue: existing?.dose ?? "")
		_category = State(initialValue: existing?.category ?? "Autre")
		_timeContext = State(initialValue: existing?.timeContext ?? "")
		_frequency = State(initialValue: existing?.frequency ?? .daily)
		_active = State(initialValue: existing?.active ?? true)
	}

	var body: some View {
		NavigationView {
			Form {
					if existing == nil {
						Section(header: Text("Modèles")) {
							Button { showingTemplates = true } label: {
								HStack {
									Image(systemName: "square.grid.2x2")
									Text("Choisir un modèle…")
									Spacer()
									Image(systemName: "chevron.right").foregroundColor(.secondary)
								}
							}
						}
					}
					Section(header: Text("Informations")) {
						TextField("Nom du supplément", text: $name)
					if existing == nil, !supplementSuggestions.isEmpty {
						VStack(alignment: .leading, spacing: 6) {
							Text("Correspondances du catalogue")
								.font(.caption)
								.foregroundColor(.secondary)
							ForEach(supplementSuggestions) { suggestion in
								Button(action: { applySupplementSuggestion(suggestion) }) {
									HStack(spacing: 10) {
										Image(systemName: "list.bullet.rectangle")
											.font(.caption)
											.foregroundColor(Color("Primary"))
											VStack(alignment: .leading, spacing: 2) {
												Text(suggestion.name)
													.font(.subheadline.weight(.semibold))
												Text(suggestion.category)
													.font(.caption)
													.foregroundColor(.secondary)
											}
										Spacer()
									}
								}
								.buttonStyle(.plain)
							}
						}
					}
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
					if existing != nil {
						Toggle("Activer le complément", isOn: $active)
					}
				}
				if existing == nil {
					Section(header: Text("Rappel personnalisé (optionnel)")) {
						Button(action: { showingCustomReminder = true }) {
							HStack {
								Image(systemName: "bell.badge")
								Text(customReminderData == nil ? "Ajouter un rappel personnalisé" : "Modifier le rappel personnalisé")
								Spacer()
								Image(systemName: "chevron.right").foregroundColor(.secondary)
							}
						}
						if let reminder = customReminderData {
							Text(reminderSummary(reminder))
								.font(.caption)
								.foregroundColor(.secondary)
							Button("Supprimer le rappel", role: .destructive) {
								customReminderData = nil
							}
						}
					}
				}
			}
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .principal) {
						SheetHeader(
							title: existing == nil ? "Nouveau supplément" : "Modifier le supplément",
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
		.sheet(isPresented: $showingCustomReminder) {
			ReminderSheet(initialData: customReminderData ?? defaultReminderData()) { data in
				customReminderData = data
			}
			.withSheetDetentsIfAvailable()
		}
			.sheet(isPresented: $showingTemplates) {
				SupplementTemplatesSheet { template in
					applySupplementSuggestion(template)
					didSelectTemplate = true
				}
				.withSheetDetentsIfAvailable()
			}
			.confirmationDialog(
				"Enregistrer dans les modèles ?",
				isPresented: $showSaveTemplatePrompt,
				titleVisibility: .visible
			) {
				Button("Créer uniquement") {
					finalizeCreate(saveAsTemplate: false)
				}
				Button("Créer + enregistrer le modèle") {
					finalizeCreate(saveAsTemplate: true)
				}
				Button("Annuler", role: .cancel) {
					pendingSupplementForCreate = nil
					pendingReminderForCreate = nil
				}
			} message: {
				Text("Voulez-vous ajouter ce supplément à votre base de modèles personnalisés ?")
			}
		}

	private func labelForFrequency(_ f: Frequency) -> String {
		switch f {
		case .daily: return "Quotidienne"
		case .timesPerDay(let n): return n <= 1 ? "1 fois/jour" : "\(n) fois/jour"
		case .weekly(let days): return days.isEmpty ? "Si besoin" : "Jours spécifiques"
		}
	}

	private var supplementSuggestions: [SupplementTemplateItem] {
		let query = normalized(name)
		let compactQuery = compact(query)
		guard compactQuery.count >= 4 else { return [] }

		return availableTemplates
			.filter { item in
				let candidate = normalized(item.name)
				let compactCandidate = compact(candidate)
				guard compactCandidate != compactQuery else { return false }
				return candidate.contains(query) || compactCandidate.contains(compactQuery)
			}
			.sorted { lhs, rhs in
				let lhsName = normalized(lhs.name)
				let rhsName = normalized(rhs.name)
				let lhsPrefix = lhsName.hasPrefix(query)
				let rhsPrefix = rhsName.hasPrefix(query)
				if lhsPrefix != rhsPrefix { return lhsPrefix && !rhsPrefix }
				return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
			}
			.prefix(5)
				.map { $0 }
	}

	private func applySupplementSuggestion(_ item: SupplementTemplateItem) {
		name = item.name
		if let suggestedDose = item.mainDose,
		   dose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			dose = suggestedDose
		}
		if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || category == "Autre" {
			category = item.category
		}
		if let suggestedTimeContext = item.defaultTimeContext,
		   timeContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			timeContext = suggestedTimeContext
		}
		didSelectTemplate = true
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
			current.active = active
			onSave(current, nil)
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
			if shouldProposeTemplateSave(for: newSupplement) {
				pendingSupplementForCreate = newSupplement
				pendingReminderForCreate = customReminderData
				showSaveTemplatePrompt = true
				return
			}
			onSave(newSupplement, customReminderData)
		}
		dismiss()
	}

	private func finalizeCreate(saveAsTemplate: Bool) {
		guard let supplement = pendingSupplementForCreate else { return }
		if saveAsTemplate {
			_ = state.addSupplementTemplate(from: supplement)
		}
		onSave(supplement, pendingReminderForCreate)
		pendingSupplementForCreate = nil
		pendingReminderForCreate = nil
		dismiss()
	}

	private func shouldProposeTemplateSave(for supplement: Supplement) -> Bool {
		guard existing == nil, !didSelectTemplate else { return false }
		let normalizedName = normalized(supplement.name)
		guard !normalizedName.isEmpty else { return false }

		let existsInBuiltIn = supplementLibrary.contains { normalized($0.name) == normalizedName }
		if existsInBuiltIn { return false }

		return !state.hasSupplementTemplate(named: supplement.name)
	}

	private func defaultReminderData() -> ReminderSheet.ReminderData {
		let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
		let title = trimmedName.isEmpty ? "Suivi du complément" : "Suivi : \(trimmedName)"
		let defaultTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
		return ReminderSheet.ReminderData(
			title: title,
			time: defaultTime,
			days: Set(1...7),
			description: "",
			notificationsEnabled: true
		)
	}

	private func reminderSummary(_ data: ReminderSheet.ReminderData) -> String {
		let comps = Calendar.current.dateComponents([.hour, .minute], from: data.time)
		let hour = comps.hour ?? 8
		let minute = comps.minute ?? 0
		let daysText = data.days.isEmpty ? "Tous les jours" : "\(data.days.count) jour(s)"
		return "\(data.title) • \(String(format: "%02d:%02d", hour, minute)) • \(daysText)"
	}

	private func normalized(_ value: String) -> String {
		value
			.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.lowercased()
	}

	private func compact(_ value: String) -> String {
		value.unicodeScalars
			.filter { CharacterSet.alphanumerics.contains($0) }
			.map(String.init)
			.joined()
	}

	private var availableTemplates: [SupplementTemplateItem] {
		var merged: [SupplementTemplateItem] = []
		var seen: Set<String> = []

		let builtInTemplates: [SupplementTemplateItem] = supplementLibrary.map {
			SupplementTemplateItem(
				id: "builtin-\($0.id)",
				name: $0.name,
				mainDose: nil,
				category: $0.categories.first?.rawValue ?? "Autre",
				detail: "Fiche neutre à personnaliser",
				defaultTimeContext: nil,
				isUserDefined: false
			)
		}

		let customTemplates: [SupplementTemplateItem] = state.customSupplementTemplates.map { template in
			SupplementTemplateItem(
				id: "custom-\(template.id.uuidString)",
				name: template.name,
				mainDose: template.dose,
				category: template.category,
				detail: template.brand ?? "Modèle personnalisé",
				defaultTimeContext: template.timeContext,
				isUserDefined: true
			)
		}

		for item in builtInTemplates + customTemplates {
			let key = normalized(item.name)
			if seen.insert(key).inserted {
				merged.append(item)
			}
		}
		return merged
	}
}

private struct SupplementTemplateItem: Identifiable {
	let id: String
	let name: String
	let mainDose: String?
	let category: String
	let detail: String
	let defaultTimeContext: String?
	let isUserDefined: Bool
}

private struct SupplementTemplatesSheet: View {
	@Environment(\.dismiss) private var dismiss
	@EnvironmentObject var state: AppState
	let onSelect: (SupplementTemplateItem) -> Void
	@State private var searchText: String = ""

	var body: some View {
		NavigationView {
			List {
				Section {
					SearchField(placeholder: "Rechercher un complément...", text: $searchText)
				}
					Section(header: Text("Catalogue et modèles")) {
						ForEach(filteredSupplements) { item in
							Button(action: { onSelect(item); dismiss() }) {
								VStack(alignment: .leading, spacing: 6) {
									HStack(spacing: 6) {
										Text(item.name)
											.font(.headline)
										if item.isUserDefined {
											Text("Perso")
												.font(.caption2.weight(.semibold))
												.padding(.horizontal, 6)
												.padding(.vertical, 2)
												.background(Color("Primary").opacity(0.12))
												.foregroundColor(Color("Primary"))
												.clipShape(Capsule())
										}
									}
									HStack(spacing: 8) {
										if let mainDose = item.mainDose {
											Text(mainDose)
											Text("•")
										}
										Text(item.category)
									}
									.font(.caption)
									.foregroundColor(.secondary)
									Text(item.detail)
										.font(.caption)
										.foregroundColor(.secondary)
								}
								.frame(maxWidth: .infinity, alignment: .leading)
							}
					}
				}
			}
			.navigationTitle("Modèles")
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Fermer") { dismiss() }
				}
			}
		}
	}

	private var filteredSupplements: [SupplementTemplateItem] {
		let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !query.isEmpty else { return allTemplates }
		return allTemplates.filter { item in
			item.name.localizedCaseInsensitiveContains(query) || item.detail.localizedCaseInsensitiveContains(query)
		}
	}

	private var allTemplates: [SupplementTemplateItem] {
		var merged: [SupplementTemplateItem] = []
		var seen: Set<String> = []

		let builtIn: [SupplementTemplateItem] = supplementLibrary.map { item in
			SupplementTemplateItem(
				id: "builtin-\(item.id)",
				name: item.name,
				mainDose: nil,
				category: item.categories.first?.rawValue ?? "Autre",
				detail: "Fiche neutre à personnaliser",
				defaultTimeContext: nil,
				isUserDefined: false
			)
		}

		let custom: [SupplementTemplateItem] = state.customSupplementTemplates.map { template in
			SupplementTemplateItem(
				id: "custom-\(template.id.uuidString)",
				name: template.name,
				mainDose: template.dose,
				category: template.category,
				detail: template.brand ?? "Modèle personnalisé",
				defaultTimeContext: template.timeContext,
				isUserDefined: true
			)
		}

		for item in builtIn + custom {
			let key = item.name
				.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
				.trimmingCharacters(in: .whitespacesAndNewlines)
				.lowercased()
			if seen.insert(key).inserted {
				merged.append(item)
			}
		}
		return merged
	}
}
