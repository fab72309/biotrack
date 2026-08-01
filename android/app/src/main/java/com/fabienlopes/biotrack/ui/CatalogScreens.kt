package com.fabienlopes.biotrack.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.fabienlopes.biotrack.data.BioTrackViewModel
import com.fabienlopes.biotrack.data.Frequency
import com.fabienlopes.biotrack.data.FrequencyKind
import com.fabienlopes.biotrack.data.ProtocolItem
import com.fabienlopes.biotrack.data.Supplement
import com.fabienlopes.biotrack.domain.Planner
import kotlinx.coroutines.delay

@Composable
fun ProtocolsScreen(viewModel: BioTrackViewModel) {
    val snapshot by viewModel.snapshot.collectAsState()
    var query by remember { mutableStateOf("") }
    var activeOnly by remember { mutableStateOf(true) }
    var category by remember { mutableStateOf<String?>(null) }
    var editor by remember { mutableStateOf<ProtocolItem?>(null) }
    var showEditor by remember { mutableStateOf(false) }
    var deleteCandidate by remember { mutableStateOf<ProtocolItem?>(null) }
    var runningTimer by remember { mutableStateOf<String?>(null) }
    var secondsLeft by remember { mutableIntStateOf(0) }

    LaunchedEffect(runningTimer) {
        while (runningTimer != null && secondsLeft > 0) {
            delay(1_000)
            secondsLeft -= 1
            if (secondsLeft == 0) runningTimer = null
        }
    }

    val categories = snapshot.protocols.mapNotNull { it.category }.distinct().sorted()
    val filtered = snapshot.protocols.filter { item ->
        (!activeOnly || item.active) && (category == null || item.category == category) &&
            (query.isBlank() || item.name.contains(query, ignoreCase = true) || item.detail.orEmpty().contains(query, ignoreCase = true))
    }.sortedBy { it.name.lowercase() }

    Scaffold(
        floatingActionButton = { FloatingActionButton(onClick = { editor = null; showEditor = true }) { Icon(Icons.Default.Add, contentDescription = "Ajouter") } }
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            item {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text("Protocoles", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                            Text("Routines, objectifs et temps dédié", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Icon(Icons.Default.Flag, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
                    }
                    Spacer(Modifier.height(12.dp))
                    OutlinedTextField(query, { query = it }, leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) }, label = { Text("Rechercher") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(selected = activeOnly, onClick = { activeOnly = !activeOnly }, label = { Text("Actifs") })
                        FilterChip(selected = category == null, onClick = { category = null }, label = { Text("Toutes") })
                        categories.forEach { itemCategory ->
                            FilterChip(selected = category == itemCategory, onClick = { category = itemCategory }, label = { Text(itemCategory) })
                        }
                    }
                }
            }
            if (filtered.isEmpty()) item { BioCard { Text("Aucun protocole ne correspond à vos filtres.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            items(filtered, key = { it.id }) { protocol ->
                ProtocolRow(
                    item = protocol,
                    isDone = Planner.isProtocolDoneToday(protocol.id, snapshot),
                    timerRunning = runningTimer == protocol.id,
                    secondsLeft = if (runningTimer == protocol.id) secondsLeft else 0,
                    onToggleDone = { viewModel.toggleProtocol(protocol.id) },
                    onToggleActive = { viewModel.toggleProtocolActive(protocol.id) },
                    onEdit = { editor = protocol; showEditor = true },
                    onDelete = { deleteCandidate = protocol },
                    onTimer = {
                        if (runningTimer == protocol.id) {
                            runningTimer = null
                            secondsLeft = 0
                        } else {
                            runningTimer = protocol.id
                            secondsLeft = (protocol.targetMinutes ?: 10) * 60
                        }
                    }
                )
            }
        }
    }

    if (showEditor) {
        ProtocolEditorDialog(existing = editor, onDismiss = { showEditor = false }) { item ->
            if (editor == null) viewModel.addProtocol(item) else viewModel.updateProtocol(item)
            showEditor = false
        }
    }
    deleteCandidate?.let { item ->
        AlertDialog(
            onDismissRequest = { deleteCandidate = null },
            title = { Text("Supprimer le protocole ?") },
            text = { Text("Supprimer « ${item.name} » ? Cette action est irréversible.") },
            confirmButton = { Button(onClick = { viewModel.deleteProtocol(item.id); deleteCandidate = null }) { Text("Supprimer") } },
            dismissButton = { TextButton(onClick = { deleteCandidate = null }) { Text("Annuler") } }
        )
    }
}

@Composable
private fun ProtocolRow(
    item: ProtocolItem,
    isDone: Boolean,
    timerRunning: Boolean,
    secondsLeft: Int,
    onToggleDone: () -> Unit,
    onToggleActive: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onTimer: () -> Unit
) {
    BioCard {
        Row(verticalAlignment = Alignment.Top) {
            Checkbox(checked = isDone, onCheckedChange = { onToggleDone() })
            Column(modifier = Modifier.weight(1f).padding(top = 10.dp)) {
                Text(item.name, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(item.detail ?: Planner.frequencyLabel(item.frequency), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                item.category?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary) }
            }
            IconButton(onClick = onEdit) { Icon(Icons.Default.Edit, contentDescription = "Modifier") }
            IconButton(onClick = onDelete) { Icon(Icons.Default.Delete, contentDescription = "Supprimer", tint = MaterialTheme.colorScheme.error) }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(if (item.active) "Activé" else "Inactif", style = MaterialTheme.typography.labelMedium, color = if (item.active) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
            IconButton(onClick = onTimer) { Icon(if (timerRunning) Icons.Default.Stop else Icons.Default.Timer, contentDescription = if (timerRunning) "Arrêter" else "Démarrer le minuteur", tint = MaterialTheme.colorScheme.primary) }
            if (timerRunning) Text("%02d:%02d".format(secondsLeft / 60, secondsLeft % 60), fontWeight = FontWeight.Bold, modifier = Modifier.padding(end = 8.dp))
            Switch(checked = item.active, onCheckedChange = { onToggleActive() })
        }
    }
}

@Composable
private fun ProtocolEditorDialog(existing: ProtocolItem?, onDismiss: () -> Unit, onSave: (ProtocolItem) -> Unit) {
    var name by remember { mutableStateOf(existing?.name.orEmpty()) }
    var detail by remember { mutableStateOf(existing?.detail.orEmpty()) }
    var category by remember { mutableStateOf(existing?.category.orEmpty()) }
    var minutes by remember { mutableStateOf((existing?.targetMinutes ?: 10).toString()) }
    var hour by remember { mutableStateOf((existing?.preferredHour ?: 8).toString()) }
    var minute by remember { mutableStateOf((existing?.preferredMinute ?: 0).toString()) }
    var weekly by remember { mutableStateOf(existing?.frequency?.kind == FrequencyKind.WEEKLY) }
    var days by remember { mutableStateOf(existing?.frequency?.days?.joinToString(",") ?: "1,2,3,4,5") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (existing == null) "Nouveau protocole" else "Modifier le protocole") },
        text = {
            Column(modifier = Modifier.padding(top = 4.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text("Nom") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                OutlinedTextField(detail, { detail = it }, label = { Text("Détail") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                OutlinedTextField(category, { category = it }, label = { Text("Catégorie") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(minutes, { minutes = it.filter(Char::isDigit).take(3) }, label = { Text("Minutes") }, modifier = Modifier.weight(1f), singleLine = true)
                    OutlinedTextField(hour, { hour = it.filter(Char::isDigit).take(2) }, label = { Text("Heure") }, modifier = Modifier.weight(1f), singleLine = true)
                    OutlinedTextField(minute, { minute = it.filter(Char::isDigit).take(2) }, label = { Text("Min.") }, modifier = Modifier.weight(1f), singleLine = true)
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = weekly, onCheckedChange = { weekly = it })
                    Text("Planifier certains jours")
                }
                if (weekly) OutlinedTextField(days, { days = it }, label = { Text("Jours 1=Lun … 7=Dim") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            }
        },
        confirmButton = { Button(onClick = {
            onSave(ProtocolItem(
                id = existing?.id ?: java.util.UUID.randomUUID().toString(),
                name = name,
                detail = detail.takeIf { it.isNotBlank() },
                category = category.takeIf { it.isNotBlank() },
                targetMinutes = minutes.toIntOrNull()?.coerceAtLeast(1),
                preferredHour = hour.toIntOrNull()?.coerceIn(0, 23),
                preferredMinute = minute.toIntOrNull()?.coerceIn(0, 59),
                frequency = if (weekly) Frequency.weekly(days.split(",").mapNotNull { it.trim().toIntOrNull()?.coerceIn(1, 7) }) else Frequency.daily(),
                active = existing?.active ?: true,
                startDate = existing?.startDate ?: System.currentTimeMillis(),
                activationSpans = existing?.activationSpans ?: emptyList()
            ))
        }, enabled = name.isNotBlank()) { Text("Enregistrer") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Annuler") } }
    )
}

@Composable
fun SupplementsScreen(viewModel: BioTrackViewModel) {
    val snapshot by viewModel.snapshot.collectAsState()
    var query by remember { mutableStateOf("") }
    var activeOnly by remember { mutableStateOf(true) }
    var category by remember { mutableStateOf<String?>(null) }
    var editor by remember { mutableStateOf<Supplement?>(null) }
    var showEditor by remember { mutableStateOf(false) }
    var deleteCandidate by remember { mutableStateOf<Supplement?>(null) }
    val categories = snapshot.supplements.mapNotNull { it.category }.distinct().sorted()
    val filtered = snapshot.supplements.filter { item ->
        (!activeOnly || item.active) && (category == null || item.category == category) &&
            (query.isBlank() || item.name.contains(query, ignoreCase = true) || item.brand.orEmpty().contains(query, ignoreCase = true) || item.dose.orEmpty().contains(query, ignoreCase = true))
    }.sortedBy { it.name.lowercase() }

    Scaffold(floatingActionButton = { FloatingActionButton(onClick = { editor = null; showEditor = true }) { Icon(Icons.Default.Add, contentDescription = "Ajouter") } }) { padding ->
        LazyColumn(modifier = Modifier.padding(padding), contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp, vertical = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text("Suppléments", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                            Text("Suivi personnel et observance", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Icon(Icons.Default.Favorite, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(28.dp))
                    }
                    Spacer(Modifier.height(12.dp))
                    OutlinedTextField(query, { query = it }, leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) }, label = { Text("Rechercher") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(selected = activeOnly, onClick = { activeOnly = !activeOnly }, label = { Text("Actifs") })
                        FilterChip(selected = category == null, onClick = { category = null }, label = { Text("Toutes") })
                        categories.forEach { itemCategory -> FilterChip(selected = category == itemCategory, onClick = { category = itemCategory }, label = { Text(itemCategory) }) }
                    }
                }
            }
            if (filtered.isEmpty()) item { BioCard { Text("Aucun supplément ne correspond à vos filtres.", color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            items(filtered, key = { it.id }) { supplement ->
                SupplementRow(
                    item = supplement,
                    isTaken = Planner.isSupplementTakenToday(supplement.id, snapshot),
                    onToggleTaken = { viewModel.toggleSupplement(supplement.id) },
                    onToggleActive = { viewModel.toggleSupplementActive(supplement.id) },
                    onEdit = { editor = supplement; showEditor = true },
                    onDelete = { deleteCandidate = supplement }
                )
            }
        }
    }

    if (showEditor) {
        SupplementEditorDialog(existing = editor, onDismiss = { showEditor = false }) { item ->
            if (editor == null) viewModel.addSupplement(item) else viewModel.updateSupplement(item)
            showEditor = false
        }
    }
    deleteCandidate?.let { item ->
        AlertDialog(onDismissRequest = { deleteCandidate = null }, title = { Text("Supprimer le supplément ?") }, text = { Text("Supprimer « ${item.name} » ? Cette action est irréversible.") }, confirmButton = { Button(onClick = { viewModel.deleteSupplement(item.id); deleteCandidate = null }) { Text("Supprimer") } }, dismissButton = { TextButton(onClick = { deleteCandidate = null }) { Text("Annuler") } })
    }
}

@Composable
private fun SupplementRow(item: Supplement, isTaken: Boolean, onToggleTaken: () -> Unit, onToggleActive: () -> Unit, onEdit: () -> Unit, onDelete: () -> Unit) {
    BioCard {
        Row(verticalAlignment = Alignment.Top) {
            Checkbox(checked = isTaken, onCheckedChange = { onToggleTaken() })
            Column(modifier = Modifier.weight(1f).padding(top = 10.dp)) {
                Text(item.name, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                val metadata = listOfNotNull(item.dose, item.brand, item.timeContext).joinToString(" · ")
                Text(metadata.ifBlank { Planner.frequencyLabel(item.frequency) }, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                item.category?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary) }
            }
            IconButton(onClick = onEdit) { Icon(Icons.Default.Edit, contentDescription = "Modifier") }
            IconButton(onClick = onDelete) { Icon(Icons.Default.Delete, contentDescription = "Supprimer", tint = MaterialTheme.colorScheme.error) }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(if (item.active) "Activé" else "Inactif", style = MaterialTheme.typography.labelMedium, color = if (item.active) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
            Switch(checked = item.active, onCheckedChange = { onToggleActive() })
        }
    }
}

@Composable
private fun SupplementEditorDialog(existing: Supplement?, onDismiss: () -> Unit, onSave: (Supplement) -> Unit) {
    var name by remember { mutableStateOf(existing?.name.orEmpty()) }
    var brand by remember { mutableStateOf(existing?.brand.orEmpty()) }
    var dose by remember { mutableStateOf(existing?.dose.orEmpty()) }
    var category by remember { mutableStateOf(existing?.category.orEmpty()) }
    var context by remember { mutableStateOf(existing?.timeContext.orEmpty()) }
    var hour by remember { mutableStateOf((existing?.timeOfDay?.div(60) ?: 8).toString()) }
    var minute by remember { mutableStateOf((existing?.timeOfDay?.rem(60) ?: 0).toString()) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (existing == null) "Nouveau supplément" else "Modifier le supplément") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text("Nom") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                OutlinedTextField(brand, { brand = it }, label = { Text("Marque (facultatif)") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                OutlinedTextField(dose, { dose = it }, label = { Text("Dose / repère (facultatif)") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                OutlinedTextField(category, { category = it }, label = { Text("Catégorie") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                OutlinedTextField(context, { context = it }, label = { Text("Contexte horaire") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(hour, { hour = it.filter(Char::isDigit).take(2) }, label = { Text("Heure") }, modifier = Modifier.weight(1f), singleLine = true)
                    OutlinedTextField(minute, { minute = it.filter(Char::isDigit).take(2) }, label = { Text("Min.") }, modifier = Modifier.weight(1f), singleLine = true)
                }
            }
        },
        confirmButton = { Button(onClick = { onSave(Supplement(id = existing?.id ?: java.util.UUID.randomUUID().toString(), name = name, brand = brand.takeIf { it.isNotBlank() }, dose = dose.takeIf { it.isNotBlank() }, category = category.takeIf { it.isNotBlank() }, timeContext = context.takeIf { it.isNotBlank() }, timeOfDay = (hour.toIntOrNull()?.coerceIn(0, 23) ?: 8) * 60 + (minute.toIntOrNull()?.coerceIn(0, 59) ?: 0), active = existing?.active ?: true, activationSpans = existing?.activationSpans ?: emptyList())) }, enabled = name.isNotBlank()) { Text("Enregistrer") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Annuler") } }
    )
}
