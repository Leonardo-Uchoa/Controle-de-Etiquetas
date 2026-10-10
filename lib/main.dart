import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const EtiquetasApp()); }

DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
String dateText(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
DateTime addMonths(DateTime d, int n) {
  final month = d.month - 1 + n;
  final year = d.year + month ~/ 12;
  final newMonth = month % 12 + 1;
  final last = DateTime(year, newMonth + 1, 0).day;
  return DateTime(year, newMonth, d.day > last ? last : d.day);
}

enum Status { vencido, hoje, proximo, seguro }
Status statusOf(DateTime validity, DateTime reference) {
  final v = day(validity), r = day(reference);
  if (v.isBefore(r)) return Status.vencido;
  if (v.isAtSameMomentAs(r)) return Status.hoje;
  if (v.isBefore(addMonths(r, 2))) return Status.proximo;
  return Status.seguro;
}
String statusName(Status s) => switch(s) {
  Status.vencido => 'Vencido', Status.hoje => 'Vence hoje',
  Status.proximo => 'Menos de 2 meses', Status.seguro => '2 meses ou mais'
};
Color statusColor(Status s) => switch(s) {
  Status.vencido => Colors.red.shade700, Status.hoje => Colors.deepOrange,
  Status.proximo => Colors.amber.shade800, Status.seguro => Colors.green.shade700
};

class Produto {
  final String codigo, nome;
  final DateTime validade;
  const Produto(this.codigo, this.nome, this.validade);
  Map<String, dynamic> toJson() => {'codigo': codigo, 'nome': nome, 'validade': validade.toIso8601String()};
  factory Produto.fromJson(Map<String, dynamic> json) => Produto(json['codigo'] as String, json['nome'] as String, DateTime.parse(json['validade'] as String));
}

class EtiquetasApp extends StatelessWidget {
  const EtiquetasApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Controle de Etiquetas', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087D46)), useMaterial3: true),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final List<Produto> _produtos = [];
  int _tab = 0;
  String _busca = '';
  Status? _filtro;
  DateTime _referencia = day(DateTime.now());
  final _codigo = TextEditingController(), _nome = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _validade;
  String? _codigoOriginal;
  bool _carregando = true;

  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); _codigo.dispose(); _nome.dispose(); super.dispose(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('produtos_v1');
    if (raw != null) {
      try { _produtos.addAll((jsonDecode(raw) as List).map((e) => Produto.fromJson(Map<String, dynamic>.from(e as Map)))); }
      catch (_) { if (mounted) _toast('Não foi possível ler os dados salvos.'); }
    }
    if (mounted) setState(() => _carregando = false);
  }
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('produtos_v1', jsonEncode(_produtos.map((p) => p.toJson()).toList()));
  }
  void _toast(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  void _clearForm() { _codigo.clear(); _nome.clear(); _validade = null; _codigoOriginal = null; }
  void _edit(Produto p) { setState(() { _codigoOriginal = p.codigo; _codigo.text = p.codigo; _nome.text = p.nome; _validade = p.validade; _tab = 1; }); }
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_validade == null) { _toast('Selecione a data de validade.'); return; }
    final codigo = _codigo.text.trim();
    if (_produtos.any((p) => p.codigo == codigo && p.codigo != _codigoOriginal)) {
      _toast('Este código já existe. Edite o produto cadastrado.'); return;
    }
    setState(() {
      if (_codigoOriginal != null) _produtos.removeWhere((p) => p.codigo == _codigoOriginal);
      _produtos.add(Produto(codigo, _nome.text.trim(), _validade!));
      _clearForm(); _tab = 2;
    });
    await _save(); _toast('Produto salvo com sucesso.');
  }
  Future<void> _delete(Produto p) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir produto?'), content: Text('${p.codigo} — ${p.nome}'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir'))]));
    if (confirm == true) { setState(() => _produtos.removeWhere((e) => e.codigo == p.codigo)); await _save(); }
  }
  List<Produto> get _ordenados => [..._produtos]..sort((a,b) { final c = a.validade.compareTo(b.validade); return c != 0 ? c : a.codigo.compareTo(b.codigo); });
  Widget _statusChip(Status s) => Chip(label: Text(statusName(s)), backgroundColor: statusColor(s).withValues(alpha: .12), labelStyle: TextStyle(color: statusColor(s), fontWeight: FontWeight.bold), side: BorderSide.none);
  Widget _produtoCard(Produto p) {
    final s = statusOf(p.validade, DateTime.now());
    return Card(child: ListTile(
      leading: CircleAvatar(backgroundColor: statusColor(s).withValues(alpha: .15), child: Icon(Icons.inventory_2_outlined, color: statusColor(s))),
      title: Text(p.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Código: ${p.codigo}'), Text('Validade: ${dateText(p.validade)}'), _statusChip(s)]),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(onSelected: (v) => v == 'editar' ? _edit(p) : _delete(p),
        itemBuilder: (_) => [const PopupMenuItem(value: 'editar', child: Text('Editar')), const PopupMenuItem(value: 'excluir', child: Text('Excluir'))]),
    ));
  }
  Widget _summaryCard(String title, int count, Color color, Status? filter) => InkWell(
    onTap: () => setState(() { _filtro = filter; _tab = 2; }),
    child: Card(color: color.withValues(alpha: .1), child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$count', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)), Text(title)]))));
  Widget _dashboard() {
    final now = DateTime.now();
    int count(Status s) => _produtos.where((p) => statusOf(p.validade, now) == s).length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Visão geral', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      Text('Hoje: ${dateText(now)}'), const SizedBox(height: 14),
      _summaryCard('Produtos cadastrados', _produtos.length, Colors.blue.shade700, null),
      _summaryCard('Verde — 2 meses ou mais', count(Status.seguro), Colors.green.shade700, Status.seguro),
      _summaryCard('Amarelo — menos de 2 meses', count(Status.proximo), Colors.amber.shade800, Status.proximo),
      _summaryCard('Vencem hoje', count(Status.hoje), Colors.deepOrange, Status.hoje),
      _summaryCard('Vermelho — vencidos', count(Status.vencido), Colors.red.shade700, Status.vencido),
      const SizedBox(height: 14), FilledButton.icon(onPressed: () => setState(() => _tab = 1), icon: const Icon(Icons.add), label: const Text('Cadastrar produto')),
    ]);
  }
  Widget _cadastro() => Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(18), children: [
    Text(_codigoOriginal == null ? 'Novo produto' : 'Editar produto', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
    const SizedBox(height: 20),
    TextFormField(controller: _codigo, decoration: const InputDecoration(labelText: 'Código do produto', border: OutlineInputBorder()),
      validator: (v) => v == null || v.trim().isEmpty ? 'Informe o código' : null),
    const SizedBox(height: 14),
    TextFormField(controller: _nome, decoration: const InputDecoration(labelText: 'Nome do produto', border: OutlineInputBorder()),
      validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null),
    const SizedBox(height: 14),
    OutlinedButton.icon(icon: const Icon(Icons.calendar_month),
      label: Text(_validade == null ? 'Selecionar validade da etiqueta' : 'Validade: ${dateText(_validade!)}'),
      onPressed: () async { final d = await showDatePicker(context: context, initialDate: _validade ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => _validade = d); }),
    const SizedBox(height: 20), FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.save), label: const Text('Salvar produto')),
    if (_codigoOriginal != null) TextButton(onPressed: () => setState(_clearForm), child: const Text('Cancelar edição')),
  ]));
  Widget _lista() {
    final filtrados = _ordenados.where((p) => (p.codigo.toLowerCase().contains(_busca.toLowerCase()) || p.nome.toLowerCase().contains(_busca.toLowerCase())) && (_filtro == null || statusOf(p.validade, DateTime.now()) == _filtro)).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar código ou nome', border: OutlineInputBorder()), onChanged: (v) => setState(() => _busca = v))),
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
        ChoiceChip(label: const Text('Todos'), selected: _filtro == null, onSelected: (_) => setState(() => _filtro = null)), const SizedBox(width: 6),
        for (final s in Status.values) ...[ChoiceChip(label: Text(statusName(s)), selected: _filtro == s, onSelected: (_) => setState(() => _filtro = s)), const SizedBox(width: 6)],
      ])),
      Expanded(child: filtrados.isEmpty ? const Center(child: Text('Nenhum produto encontrado.')) : ListView.builder(padding: const EdgeInsets.all(8), itemCount: filtrados.length, itemBuilder: (_, i) => _produtoCard(filtrados[i]))),
    ]);
  }
  List<Produto> get _vencidosRelatorio => _ordenados.where((p) => day(p.validade).isBefore(_referencia)).toList();
  String _csv() {
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    final lines = <String>['Código;Nome;Validade da etiqueta'];
    for (final p in _vencidosRelatorio) { lines.add('${esc(p.codigo)};${esc(p.nome)};${dateText(p.validade)}'); }
    return '\uFEFF${lines.join('\r\n')}\r\n';
  }
  Future<void> _export() async {
    if (_vencidosRelatorio.isEmpty) { _toast('Nenhuma etiqueta vencida nesta data.'); return; }
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/etiquetas_vencidas_${_referencia.year}${_referencia.month.toString().padLeft(2,'0')}${_referencia.day.toString().padLeft(2,'0')}.csv';
      await File(path).writeAsString(_csv(), encoding: utf8);
      await Share.shareXFiles([XFile(path, mimeType: 'text/csv')], text: 'Relatório de etiquetas vencidas em ${dateText(_referencia)}');
    } catch (e) { _toast('Falha ao gerar relatório: $e'); }
  }
  Widget _relatorio() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Relatório de vencidos', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8), const Text('Produtos cuja etiqueta venceu antes da data de referência.'),
    const SizedBox(height: 16),
    OutlinedButton.icon(icon: const Icon(Icons.event), label: Text('Data de referência: ${dateText(_referencia)}'), onPressed: () async {
      final d = await showDatePicker(context: context, initialDate: _referencia, firstDate: DateTime(2000), lastDate: DateTime(2100));
      if (d != null) setState(() => _referencia = d);
    }),
    TextButton(onPressed: () => setState(() => _referencia = day(DateTime.now())), child: const Text('Usar data de hoje')),
    const SizedBox(height: 8), Text('${_vencidosRelatorio.length} etiqueta(s) vencida(s)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
    const SizedBox(height: 8), FilledButton.icon(onPressed: _export, icon: const Icon(Icons.ios_share), label: const Text('Gerar e compartilhar relatório CSV')),
    const SizedBox(height: 12),
    if (_vencidosRelatorio.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nenhuma etiqueta vencida nessa data.')),
    for (final p in _vencidosRelatorio) Card(child: ListTile(title: Text(p.codigo, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(p.nome), trailing: Text(dateText(p.validade), style: TextStyle(color: Colors.red.shade700)))),
  ]);
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Controle de Etiquetas'), backgroundColor: Theme.of(context).colorScheme.primaryContainer),
    body: _carregando ? const Center(child: CircularProgressIndicator()) : IndexedStack(index: _tab, children: [_dashboard(), _cadastro(), _lista(), _relatorio()]),
    bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i), destinations: const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Início'),
      NavigationDestination(icon: Icon(Icons.add_box_outlined), selectedIcon: Icon(Icons.add_box), label: 'Cadastrar'),
      NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Produtos'),
      NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Relatórios'),
    ]),
  );
}
