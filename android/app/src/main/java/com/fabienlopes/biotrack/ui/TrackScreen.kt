package com.fabienlopes.biotrack.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.fabienlopes.biotrack.data.BioTrackViewModel
import com.fabienlopes.biotrack.data.Metric
import com.fabienlopes.biotrack.data.MetricKind
import com.fabienlopes.biotrack.domain.Statistics
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun TrackScreen(viewModel: BioTrackViewModel) {
    val snapshot by viewModel.snapshot.collectAsState()
    var selectedMetricId by remember(snapshot.metrics) { mutableStateOf(snapshot.metrics.firstOrNull()?.id) }
    var addMetric by remember { mutableStateOf(false) }
    var addEntryFor by remember { mutableStateOf<String?>(null) }
    val selectedMetric = snapshot.metrics.firstOrNull { it.id == selectedMetricId } ?: snapshot.metrics.firstOrNull()

    LazyColumn(
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Suivi", style = MaterialTheme.typography.headlineSmall, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
                    Text("Métriques et observations quotidiennes", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                }
                IconButton(onClick = { addMetric = true }) { Icon(Icons.Default.Add, contentDescription = "Créer une métrique") }
            }
        }
        if (snapshot.metrics.isEmpty()) {
            item {
                BioCard { Text("Créez votre première métrique pour commencer à observer vos données.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
            }
        } else {
            item {
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 1.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    items(snapshot.metrics, key = { it.id }) { metric ->
                        FilterChip(
                            selected = metric.id == selectedMetric?.id,
                            onClick = { selectedMetricId = metric.id },
                            label = { Text(metric.name, maxLines = 1) },
                            leadingIcon = if (metric.id == selectedMetric?.id) ({ Icon(Icons.Default.Tune, contentDescription = null, modifier = Modifier.size(16.dp)) }) else null
                        )
                    }
                }
            }
            selectedMetric?.let { metric ->
                item {
                    MetricChartCard(metric, snapshot, onAdd = { addEntryFor = metric.id })
                }
                item {
                    BioCard {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(metric.name, style = MaterialTheme.typography.titleMedium, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
                                Text("Entrées récentes", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            OutlinedButton(onClick = { addEntryFor = metric.id }) { Icon(Icons.Default.Add, contentDescription = null); Spacer(Modifier.width(4.dp)); Text("Ajouter") }
                        }
                        val entries = snapshot.metricEntries.filter { it.metricId == metric.id }.sortedByDescending { it.date }.take(12)
                        if (entries.isEmpty()) {
                            Spacer(Modifier.height(12.dp))
                            Text("Aucune entrée pour le moment.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                        } else {
                            entries.forEach { entry ->
                                Row(modifier = Modifier.fillMaxWidth().padding(vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(formatDate(entry.date), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        entry.notes?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                                    }
                                    Text(formatValue(entry.value, metric.kind, metric.unit), fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                }
            }
        }
        item {
            BioCard {
                Text("Check-ins récents", style = MaterialTheme.typography.titleMedium, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
                snapshot.dailyCheckIns.sortedByDescending { it.date }.take(4).forEach { checkIn ->
                    Row(modifier = Modifier.fillMaxWidth().padding(vertical = 7.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("${formatDate(checkIn.date)} · ${checkIn.period.displayName}", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodySmall)
                        Text("Énergie ${checkIn.energy}/10 · Humeur ${checkIn.mood}/10", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                if (snapshot.dailyCheckIns.isEmpty()) Text("Les check-ins du jour apparaissent ici.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }

    if (addMetric) {
        AddMetricDialog(onDismiss = { addMetric = false }) { name, kind, unit ->
            viewModel.addMetric(name, kind, unit)
            addMetric = false
        }
    }
    addEntryFor?.let { metricId ->
        val metric = snapshot.metrics.firstOrNull { it.id == metricId }
        if (metric != null) AddEntryDialog(metric, onDismiss = { addEntryFor = null }) { value, notes ->
            viewModel.addMetricEntry(metric.id, value, notes)
            addEntryFor = null
        }
    }
}

@Composable
private fun MetricChartCard(metric: Metric, snapshot: com.fabienlopes.biotrack.data.AppSnapshot, onAdd: () -> Unit) {
    val series = Statistics.chartSeries(snapshot, metric.id)
    BioCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(modifier = Modifier.weight(1f)) {
                Text("${metric.name} · 30 jours", style = MaterialTheme.typography.titleMedium, fontWeight = androidx.compose.ui.text.font.FontWeight.Bold)
                Text(if (series.isEmpty()) "Pas encore assez de données" else "${series.size} jours mesurés", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            IconButton(onClick = onAdd) { Icon(Icons.Default.Add, contentDescription = "Ajouter une entrée") }
        }
        Spacer(Modifier.height(12.dp))
        if (series.size >= 2) {
            val values = series.map { it.value }
            val median = values.sorted()[values.lastIndex / 2]
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(
                    modifier = Modifier.width(52.dp).height(180.dp),
                    verticalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(formatValue(values.maxOrNull() ?: 0.0, metric.kind, metric.unit), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                    Text(formatValue(median, metric.kind, metric.unit), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                    Text(formatValue(values.minOrNull() ?: 0.0, metric.kind, metric.unit), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                }
                LineChart(series, modifier = Modifier.weight(1f).height(180.dp))
            }
            Row(modifier = Modifier.padding(start = 52.dp).fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(formatChartDate(series.first().day), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(formatChartDate(series.last().day), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Début · ${formatValue(series.first().value, metric.kind, metric.unit)}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("Fin · ${formatValue(series.last().value, metric.kind, metric.unit)}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (series.zipWithNext().any { (left, right) -> daysBetween(left.day, right.day) > 1 }) {
                Text("Les segments interrompus indiquent un jour sans saisie.", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            Text("Ajoutez au moins deux journées pour afficher la tendance.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun LineChart(points: List<com.fabienlopes.biotrack.domain.ChartPoint>, modifier: Modifier = Modifier) {
    val primary = MaterialTheme.colorScheme.primary
    val outline = MaterialTheme.colorScheme.outline
    Canvas(modifier = modifier) {
        if (points.size < 2) return@Canvas
        val values = points.map { it.value }
        val minValue = values.minOrNull() ?: 0.0
        val maxValue = values.maxOrNull() ?: 1.0
        val spread = (maxValue - minValue).takeIf { it > 0.000001 } ?: 1.0
        val startDay = points.first().day
        val daySpan = (points.last().day - startDay).coerceAtLeast(1L)
        val chartHeight = size.height - 12.dp.toPx()
        val yFor = { value: Double -> size.height - ((value - minValue) / spread).toFloat() * chartHeight - 6.dp.toPx() }
        listOf(0f, 0.5f, 1f).forEach { fraction ->
            val y = 6.dp.toPx() + chartHeight * (1f - fraction)
            drawLine(outline.copy(alpha = if (fraction == 0.5f) 0.4f else 0.18f), Offset(0f, y), Offset(size.width, y), strokeWidth = 1.dp.toPx())
        }
        val path = Path()
        points.forEachIndexed { index, point ->
            val x = size.width * ((point.day - startDay).toFloat() / daySpan.toFloat())
            val y = yFor(point.value)
            val hasGap = index > 0 && daysBetween(points[index - 1].day, point.day) > 1
            if (index == 0 || hasGap) path.moveTo(x, y) else path.lineTo(x, y)
        }
        drawPath(path, primary, style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round))
        points.forEach { point ->
            val x = size.width * ((point.day - startDay).toFloat() / daySpan.toFloat())
            val y = yFor(point.value)
            drawCircle(primary, radius = 3.dp.toPx(), center = Offset(x, y))
        }
    }
}

private val chartDateFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM", Locale.FRENCH)

private fun formatChartDate(timestamp: Long): String = chartDateFormatter.format(Instant.ofEpochMilli(timestamp).atZone(ZoneId.systemDefault()))

private fun daysBetween(start: Long, end: Long): Long = java.time.temporal.ChronoUnit.DAYS.between(
    Instant.ofEpochMilli(start).atZone(ZoneId.systemDefault()).toLocalDate(),
    Instant.ofEpochMilli(end).atZone(ZoneId.systemDefault()).toLocalDate()
)

@Composable
private fun AddMetricDialog(onDismiss: () -> Unit, onSave: (String, MetricKind, String?) -> Unit) {
    var name by remember { mutableStateOf("") }
    var unit by remember { mutableStateOf("") }
    var duration by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Créer une métrique") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text("Nom") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                OutlinedTextField(unit, { unit = it }, label = { Text("Unité (facultatif)") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    androidx.compose.material3.Checkbox(checked = duration, onCheckedChange = { duration = it })
                    Text("Durée en heures/minutes")
                }
            }
        },
        confirmButton = { Button(onClick = { onSave(name, if (duration) MetricKind.HOURS_MINUTES else MetricKind.NUMBER, unit.takeIf { it.isNotBlank() }) }, enabled = name.isNotBlank()) { Text("Créer") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Annuler") } }
    )
}

@Composable
private fun AddEntryDialog(metric: Metric, onDismiss: () -> Unit, onSave: (Double, String?) -> Unit) {
    var value by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Ajouter · ${metric.name}") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(value, { value = it }, label = { Text(if (metric.kind == MetricKind.HOURS_MINUTES) "Valeur en minutes" else "Valeur") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                OutlinedTextField(notes, { notes = it }, label = { Text("Note (facultatif)") }, modifier = Modifier.fillMaxWidth(), minLines = 2)
            }
        },
        confirmButton = { Button(onClick = { value.toDoubleOrNull()?.let { onSave(it, notes.takeIf { it.isNotBlank() }) } }, enabled = value.toDoubleOrNull() != null) { Text("Ajouter") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Annuler") } }
    )
}
