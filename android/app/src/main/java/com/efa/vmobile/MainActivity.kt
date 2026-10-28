package com.efa.vmobile

import android.app.Activity
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.util.UUID

// Primera versión: pedidos guardados en SQLite local. No sincroniza con SAP ni SQL Server.
data class Pedido(val id: String, val cliente: String, val articulo: String, val piezas: Int, val kilos: Double, val estado: String)

class PedidosDb(context: Activity) : SQLiteOpenHelper(context, "vmobile_local.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE pedidos (id TEXT PRIMARY KEY, cliente TEXT NOT NULL, articulo TEXT NOT NULL, piezas INTEGER NOT NULL, kilos REAL NOT NULL, estado TEXT NOT NULL)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
    fun agregar(p: Pedido) {
        writableDatabase.insertOrThrow("pedidos", null, ContentValues().apply {
            put("id", p.id); put("cliente", p.cliente); put("articulo", p.articulo)
            put("piezas", p.piezas); put("kilos", p.kilos); put("estado", p.estado)
        })
    }
    fun consultar(): List<Pedido> {
        val result = mutableListOf<Pedido>()
        readableDatabase.rawQuery("SELECT id,cliente,articulo,piezas,kilos,estado FROM pedidos ORDER BY rowid DESC", null).use { c ->
            while (c.moveToNext()) result.add(Pedido(c.getString(0), c.getString(1), c.getString(2), c.getInt(3), c.getDouble(4), c.getString(5)))
        }
        return result
    }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val db = PedidosDb(this)
        setContent { MaterialTheme { VMobileScreen(db) } }
    }
}

@Composable
fun VMobileScreen(db: PedidosDb) {
    var pantalla by remember { mutableStateOf("inicio") }
    var cliente by remember { mutableStateOf("") }
    var articulo by remember { mutableStateOf("") }
    var piezas by remember { mutableStateOf("") }
    var kilos by remember { mutableStateOf("") }
    var pedidos by remember { mutableStateOf(db.consultar()) }
    var mensaje by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().padding(20.dp)) {
        Text("VMobile", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(12.dp))
        when (pantalla) {
            "inicio" -> {
                Text("Punto de venta móvil · Versión inicial")
                Spacer(Modifier.height(20.dp))
                Button(onClick = { pantalla = "nuevo" }) { Text("Nuevo pedido") }
                Button(onClick = { pedidos = db.consultar(); pantalla = "lista" }) { Text("Consultar pedidos") }
                OutlinedButton(onClick = { pantalla = "ventas" }) { Text("Ventas (próximamente)") }
            }
            "ventas" -> {
                Text("El módulo de ventas SAP está pendiente de integración.")
                OutlinedButton(onClick = { pantalla = "inicio" }) { Text("Volver") }
            }
            "nuevo" -> {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    OutlinedTextField(cliente, { cliente = it }, label = { Text("Código de cliente") })
                    OutlinedTextField(articulo, { articulo = it }, label = { Text("Código de artículo") })
                    OutlinedTextField(piezas, { piezas = it }, label = { Text("Piezas") })
                    OutlinedTextField(kilos, { kilos = it }, label = { Text("Kilogramos") })
                    if (mensaje.isNotEmpty()) Text(mensaje)
                    Button(onClick = {
                        val p = piezas.toIntOrNull(); val k = kilos.toDoubleOrNull()
                        if (cliente.isBlank() || articulo.isBlank() || p == null || p <= 0 || k == null || !k.isFinite() || k <= 0) {
                            mensaje = "Capture cliente, artículo, piezas y kilos válidos."
                        } else {
                            db.agregar(Pedido(UUID.randomUUID().toString(), cliente.trim(), articulo.trim(), p, k, "BORRADOR"))
                            pedidos = db.consultar(); cliente = ""; articulo = ""; piezas = ""; kilos = ""; mensaje = ""
                            pantalla = "lista"
                        }
                    }) { Text("Guardar pedido local") }
                    OutlinedButton(onClick = { pantalla = "inicio" }) { Text("Volver") }
                }
            }
            "lista" -> {
                Text("Pedidos guardados en este dispositivo", style = MaterialTheme.typography.titleMedium)
                LazyColumn(Modifier.weight(1f)) {
                    items(pedidos, key = { it.id }) { p ->
                        Card(Modifier.fillMaxWidth().padding(vertical = 5.dp)) {
                            Column(Modifier.padding(12.dp)) {
                                Text("Cliente: ${p.cliente} · ${p.estado}")
                                Text("${p.articulo} · ${p.piezas} piezas · ${p.kilos} kg")
                                Text("ID: ${p.id.take(8)}", style = MaterialTheme.typography.bodySmall)
                            }
                        }
                    }
                }
                OutlinedButton(onClick = { pantalla = "inicio" }) { Text("Volver") }
            }
        }
    }
}