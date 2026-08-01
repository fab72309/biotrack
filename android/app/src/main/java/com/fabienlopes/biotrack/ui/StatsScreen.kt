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
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.fabienlopes.biotrack.data.BioTrackViewModel
import com.fabienlopes.biotrack.data.Metric
import com.fabienlopes.biotrack.data.NOf1Experiment
import com.fabienlopes.biotrack.domain.Statistics
import java.util.Locale

@Composable
fun StatsScreen(viewModel: BioTrackViewModel) {
    val snapshot by viewModel.snapshot.collectAsState()
    var selectedA by remember(snapshot.metrics) { mutableStateOf(snapshot.metrics.getOrNull(0)?.id) }
    var selectedB by remember(snapshot.metrics) { mutableStateOf(snapshot.metrics.getOrNull(1)?.id) }
    var showExperimentDialog by remember { mutableStateOf(false) }
    var observationExperiment by remember { mutableStateOf<NOf1Experiment?>(null) }
    val metricA = snapshot.metrics.firstOrNull { it.id == selectedA }
    val metricB = snapshot.metrics.firstOrNull { it.id == selectedB }

    LazyColumn(contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 16.dp, vertical = 14.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Statistiques", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    Text("Tendances, associations et expériences N-of-1", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                IconButton(onClick = { viewModel.refreshInsights() }) { Icon(Icons.Default.Refresh, contentDescription = "Rafraîchir") }
            }
        }
        item {
            BioCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Comparaison multi-séries", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    Icon(Icons.AutoMirrored.Filled.ShowChart, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                }
                Text("Les séries sont centrées et robustement standardisées pour comparer des unités différentes.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(10.dp))
                if (snapshot.metrics.isEmpty()) {
                    Text("Ajoutez des métriques dans l'onglet Suivi.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        MetricPicker("Série A", metricA, snapshot.metrics, Modifier.weight(1f)) { selectedA = it }
                        MetricPicker("Série B", metricB, snapshot.metrics, Modifier.weight(1f)) { selectedB = it }
                    }
                    Spacer(Modifier.height(12.dp))
                    val seriesA = metricA?.let { Statistics.chartSeries(snapshot, it.id).associateBy { point -> point.day } }.orEmpty()
                    val seriesB = metricB?.let { Statistics.chartSeries(snapshot, it.id).associateBy { point -> point.day } }.orEmpty()
                    val days = (seriesA.keys intersect seriesB.keys).sorted()
                    if (days.size >= 3) {
                        val a = Statistics.robustStandardScores(days.map { seriesA.getValue(it).value })
                        val b = Statistics.robustStandardScores(days.map { seriesB.getValue(it).value })
                        AccessibleComparisonChart(
                            listOf(a, b),
                            modifier = Modifier.fillMaxWidth()
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            LegendDot(MaterialTheme.colorScheme.primary, metricA?.name ?: "A")
                            LegendDot(MaterialTheme.colorScheme.secondary, metricB?.name ?: "B")
                        }
                    } else Text("Il faut au moins trois journées alignées pour comparer les séries.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item {
            BioCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Insights de corrélation", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    Text("Exploratoire", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (snapshot.correlationInsights.isEmpty()) {
                    Spacer(Modifier.height(8.dp))
                    Text("Pas encore de signal suffisamment robuste sur les données disponibles.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    snapshot.correlationInsights.take(6).forEach { insight ->
                        val a = snapshot.metrics.firstOrNull { it.id == insight.metricAId }?.name ?: "Métrique A"
                        val b = snapshot.metrics.firstOrNull { it.id == insight.metricBId }?.name ?: "Métrique B"
                        Column(modifier = Modifier.padding(vertical = 7.dp)) {
                            Text("$a · $b", fontWeight = FontWeight.SemiBold)
                            Text(insight.summary, style = MaterialTheme.typography.bodySmall)
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
                                InsightStat("Pearson", insight.pearson.formatCorrelation(), Modifier.weight(1f))
                                InsightStat("Spearman", insight.spearman?.formatCorrelation() ?: "—", Modifier.weight(1f))
                                InsightStat("Jours", insight.sampleSize.toString(), Modifier.weight(1f))
                            }
                            Text("${insight.evidence?.displayName ?: "À confirmer"} · exploratoire", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp))
                        }
                    }
                }
            }
        }
        item {
            BioCard {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Expériences N-of-1", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                    OutlinedButton(onClick = { showExperimentDialog = true }) { Icon(Icons.Default.Add, contentDescription = null); Spacer(Modifier.size(4.dp)); Text("Créer") }
                }
                if (snapshot.experiments.isEmpty()) Text("Structurez une question personnelle avec une phase contrôle puis intervention.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                snapshot.experiments.forEach { experiment ->
                    val summary = Statistics.experimentSummary(experiment, snapshot.experimentObservations)
                    Column(modifier = Modifier.padding(vertical = 7.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(experiment.title, fontWeight = FontWeight.SemiBold)
                                Text(experiment.hypothesis.ifBlank { "Hypothèse non renseignée" }, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            TextButton(onClick = { observationExperiment = experiment }) { Text("Observer") }
                        }
                        val delta = summary.delta?.let { "Δ ${"%.2f".format(it)}" } ?: "Pas assez d'observations"
                        Text("Contrôle ${summary.controlAverage?.let { "%.2f".format(it) } ?: "—"} · Intervention ${summary.interventionAverage?.let { "%.2f".format(it) } ?: "—"} · $delta", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
        item {
            Text("Les associations et différences sont des observations exploratoires ; elles ne constituent ni diagnostic ni conseil médical.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }

    if (showExperimentDialog) {
        ExperimentDialog(metrics = snapshot.metrics, onDismiss = { showExperimentDialog = false }) { title, hypothesis, metricId, duration, phase ->
            viewModel.createExperiment(title, hypothesis, metricId, duration, phase)
            showExperimentDialog = false
        }
    }
    observationExperiment?.let { experiment ->
        ObservationDialog(experiment, onDismiss = { observationExperiment = null }) { value, notes ->
            viewModel.recordObservation(experiment.id, value, notes)
            observationExperiment = null
        }
    }
}

@Composable
private fun MetricPicker(label: String, selected: Metric?, metrics: List<Metric>, modifier: Modifier = Modifier, onSelected: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier = modifier) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        FilterChip(selected = selected != null, onClick = { expanded = !expanded }, label = { Text(selected?.name ?: "Choisir", maxLines = 1) })
        if (expanded) {
            metrics.forEach { metric -> TextButton(onClick = { onSelected(metric.id); expanded = false }) { Text(metric.name) } }
        }
    }
}

@Composable
private fun LegendDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Canvas(Modifier.size(10.dp)) { drawCircle(color) }
        Spacer(Modifier.size(4.dp))
        Text(label, style = MaterialTheme.typography.labelSmall)
    }
}

@Composable
private fun InsightStat(label: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surfaceVariant, androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
            .padding(horizontal = 10.dp, vertical = 8.dp)
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
    }
}

private fun Double.formatCorrelation(): String = String.format(Locale.FRENCH, "%.2f", this)

@Composable
private fun AccessibleComparisonChart(series: List<List<Double>>, modifier: Modifier = Modifier) {
    Column(modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(
                modifier = Modifier
                    .width(28.dp)
                    .height(180.dp),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                Text("+3", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("0", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("−3", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            ComparisonChart(series, modifier = Modifier.weight(1f).height(180.dp))
        }
        Row(modifier = Modifier.padding(start = 28.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Début", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("Fin", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text("Valeurs standardisées · 0 correspond à la médiane de la série", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
    }
}

@Composable
private fun ComparisonChart(series: List<List<Double>>, modifier: Modifier = Modifier) {
    val colors = listOf(MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.secondary)
    val outline = MaterialTheme.colorScheme.outline
    Canvas(modifier) {
        listOf(0.17f, 0.5f, 0.83f).forEach { fraction ->
            drawLine(
                outline.copy(alpha = if (fraction == 0.5f) 0.45f else 0.18f),
                Offset(0f, size.height * fraction),
                Offset(size.width, size.height * fraction),
                strokeWidth = 1.dp.toPx()
            )
        }
        series.forEachIndexed { seriesIndex, values ->
            if (values.size < 2) return@forEachIndexed
            val path = Path()
            values.forEachIndexed { index, value ->
                val x = size.width * index / (values.size - 1).toFloat()
                val y = size.height / 2f - value.coerceIn(-3.0, 3.0).toFloat() * (size.height / 6f)
                if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            drawPath(path, colors[seriesIndex % colors.size], style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round))
        }
        drawLine(outline.copy(alpha = 0.35f), Offset(0f, size.height / 2f), Offset(size.width, size.height / 2f), strokeWidth = 1.dp.toPx())
    }
}

@Composable
private fun ExperimentDialog(metrics: List<Metric>, onDismiss: () -> Unit, onSave: (String, String, String, Int, Int) -> Unit) {
    var title by remember { mutableStateOf("") }
    var hypothesis by remember { mutableStateOf("") }
    var metricId by remember { mutableStateOf(metrics.firstOrNull()?.id) }
    var duration by remember { mutableStateOf("28") }
    var phase by remember { mutableStateOf("7") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Nouvelle expérience N-of-1") }, text = {
        Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
            OutlinedTextField(title, { title = it }, label = { Text("Titre") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            OutlinedTextField(hypothesis, { hypothesis = it }, label = { Text("Hypothèse") }, modifier = Modifier.fillMaxWidth(), minLines = 2)
            Text("Métrique cible", style = MaterialTheme.typography.labelMedium)
            metrics.forEach { metric -> FilterChip(selected = metric.id == metricId, onClick = { metricId = metric.id }, label = { Text(metric.name) }) }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(duration, { duration = it }, label = { Text("Durée jours") }, modifier = Modifier.weight(1f), singleLine = true)
                OutlinedTextField(phase, { phase = it }, label = { Text("Phase jours") }, modifier = Modifier.weight(1f), singleLine = true)
            }
        }
    }, confirmButton = { Button(onClick = { metricId?.let { onSave(title, hypothesis, it, duration.toIntOrNull() ?: 28, phase.toIntOrNull() ?: 7) } }, enabled = metricId != null) { Text("Créer") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("Annuler") } })
}

@Composable
private fun ObservationDialog(experiment: NOf1Experiment, onDismiss: () -> Unit, onSave: (Double, String?) -> Unit) {
    var value by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text("Observer · ${experiment.title}") }, text = {
        Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
            Text("Valeur de la phase actuelle : ${Statistics.experimentPhase(experiment).name}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            OutlinedTextField(value, { value = it }, label = { Text("Valeur") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            OutlinedTextField(notes, { notes = it }, label = { Text("Note (facultatif)") }, modifier = Modifier.fillMaxWidth())
        }
    }, confirmButton = { Button(onClick = { value.toDoubleOrNull()?.let { onSave(it, notes.takeIf { it.isNotBlank() }) } }, enabled = value.toDoubleOrNull() != null) { Text("Enregistrer") } }, dismissButton = { TextButton(onClick = onDismiss) { Text("Annuler") } })
}
