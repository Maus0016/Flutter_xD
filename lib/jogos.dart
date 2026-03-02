import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';

class JogosPage extends StatefulWidget {
  const JogosPage({super.key});

  @override
  State<JogosPage> createState() => _JogosPageState();
}

class _JogosPageState extends State<JogosPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _initialized = false;
  String _meuUsername = "";

  // PALETA DARK PREMIUM
  final Color backgroundDark = const Color(0xFF0F0F0F);
  final Color surfaceDark = const Color(0xFF1A1A1A);
  final Color accentColor = const Color(0xFF03DAC6);

  List<Map<String, dynamic>> _meusConvites = [];
  String _esporteSelecionado = 'Futebol';
  String _localSelecionado = 'Ginásio';
  String _horarioSelecionado = '08:00';
  DateTime _dataSelecionada = DateTime.now();

  final List<String> _esportes = ['Futebol', 'Vôlei', 'Handebol'];
  final List<String> _locais = [
    'Ginásio',
    'Oktober',
    'Poliesportivo',
    'Casual',
  ];
  final List<String> _horarios = List.generate(
    14,
    (i) => '${(i + 8).toString().padLeft(2, '0')}:00',
  );

  Stream<List<Map<String, dynamic>>>? _gamesStream;

  @override
  void initState() {
    super.initState();
    _inicializarPagina();
  }

  Future<void> _inicializarPagina() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        return;
      }
      final data = await _supabase
          .from('profiles')
          .select('username, is_admin')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _isAdmin = data?['is_admin'] == true;
          _meuUsername =
              user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              data?['username'] ??
              "Jogador";
          _gamesStream = _supabase
              .from('games')
              .stream(primaryKey: ['id'])
              .order('created_at', ascending: false);
          _initialized = true;
        });
        _buscarConvites();
      }
    } catch (e) {
      if (mounted) setState(() => _initialized = true);
    }
  }

  Future<void> _buscarConvites() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final data = await _supabase
        .from('invites')
        .select()
        .eq('receiver_id', user.id)
        .eq('status', 'pending');
    if (mounted)
      setState(() => _meusConvites = List<Map<String, dynamic>>.from(data));
  }

  void _notificar(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- LÓGICA DE GESTÃO DE PARTIDAS ---

  Future<void> _salvarJogo() async {
    final nomeFinal =
        "$_esporteSelecionado - ${_dataSelecionada.day}/${_dataSelecionada.month} - $_horarioSelecionado";
    setState(() => _isLoading = true);
    try {
      await _supabase.from('games').insert({'name': nomeFinal});
      _notificar('Partida criada!', Colors.green);
    } catch (e) {
      _notificar('Erro ao criar.', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _excluirPartida(String id) async {
    try {
      await _supabase.from('games').delete().eq('id', id);
      _notificar("Partida removida", Colors.grey);
    } catch (e) {
      _notificar("Erro ao excluir", Colors.red);
    }
  }

  Future<void> _entrarNoJogo(String gameId) async {
    try {
      await _supabase.from('participants').insert({
        'game_id': gameId,
        'user_id': _supabase.auth.currentUser!.id,
        'user_name': _meuUsername,
      });
      _notificar("Presença confirmada!", Colors.green);
    } catch (e) {
      _notificar('Você já está na lista!', Colors.orange);
    }
  }

  Future<void> _sairDoJogo(String gameId) async {
    try {
      await _supabase.from('participants').delete().match({
        'game_id': gameId,
        'user_id': _supabase.auth.currentUser!.id,
      });
      _notificar('Você saiu da lista.', Colors.grey);
    } catch (e) {
      _notificar('Erro ao sair.', Colors.red);
    }
  }

  // --- INTERFACE PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    if (!_initialized)
      return Scaffold(
        backgroundColor: backgroundDark,
        body: Center(child: CircularProgressIndicator(color: accentColor)),
      );

    // Define se a tela usa o layout de colunas (Lado a Lado)
    bool isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surfaceDark,
        centerTitle: true,
        title: const Text(
          'Risk Tournament',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        actions: [
          _buildBadgeIcon(),
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: Colors.white24,
              size: 20,
            ),
            onPressed: () => _supabase.auth.signOut().then(
              (_) => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Olá, $_meuUsername!",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: isWide
                  ? Row(
                      // VISÃO LADO A LADO (Dashboard)
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ESQUERDA: FORMULÁRIO
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel("CRIAR NOVA PARTIDA"),
                                _buildFormulario(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 30),
                        // DIREITA: LISTA
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel("PARTIDAS ATIVAS"),
                              Expanded(child: _buildListaRealtime()),
                            ],
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      // VISÃO EMPILHADA (Celular)
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel("CRIAR NOVA PARTIDA"),
                          _buildFormulario(),
                          const SizedBox(height: 25),
                          _sectionLabel("PARTIDAS ATIVAS"),
                          _buildListaRealtime(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: accentColor.withOpacity(0.4),
        fontWeight: FontWeight.bold,
        fontSize: 10,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _buildBadgeIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_none_rounded,
            color: accentColor,
            size: 22,
          ),
          onPressed: _abrirPainelConvites,
        ),
        if (_meusConvites.isNotEmpty)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                '${_meusConvites.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFormulario() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildDropCompact(
            "Esporte",
            Icons.sports_soccer,
            _esporteSelecionado,
            _esportes,
            (v) => setState(() => _esporteSelecionado = v!),
          ),
          _buildDropCompact(
            "Local",
            Icons.location_on_outlined,
            _localSelecionado,
            _locais,
            (v) => setState(() => _localSelecionado = v!),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.calendar_today_rounded,
              color: accentColor,
              size: 18,
            ),
            title: Text(
              "Data: ${_dataSelecionada.day}/${_dataSelecionada.month}",
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            trailing: const Icon(
              Icons.edit_calendar_rounded,
              size: 14,
              color: Colors.white24,
            ),
            onTap: _selecionarData,
          ),
          _buildDropCompact(
            "Horário",
            Icons.access_time_rounded,
            _horarioSelecionado,
            _horarios,
            (v) => setState(() => _horarioSelecionado = v!),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _salvarJogo,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 15,
                      width: 15,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "PUBLICAR JOGO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropCompact(
    String label,
    IconData icon,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      isDense: true,
      dropdownColor: surfaceDark,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        prefixIcon: Icon(icon, color: accentColor, size: 18),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white10),
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildListaRealtime() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _gamesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator(color: accentColor));
        final games = snapshot.data!;
        if (games.isEmpty)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "Nenhuma partida ativa.",
                style: TextStyle(color: Colors.white24, fontSize: 12),
              ),
            ),
          );
        return ListView.builder(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final g = games[index];
            return Card(
              color: surfaceDark,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                onTap: () => _abrirSala(g),
                dense: true,
                leading: Icon(
                  Icons.sports_soccer,
                  color: accentColor,
                  size: 20,
                ),
                title: Text(
                  g['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                trailing: _isAdmin
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _excluirPartida(g['id'].toString()),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.delete_sweep_outlined,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.white10,
                      ),
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAIS (CONVITES, SALA E CONVIDAR) ---

  Future<void> _selecionarData() async {
    final DateTime? colhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: accentColor,
            surface: surfaceDark,
          ),
        ),
        child: child!,
      ),
    );
    if (colhida != null) setState(() => _dataSelecionada = colhida);
  }

  void _abrirPainelConvites() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "MEUS CONVITES",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const Divider(color: Colors.white10),
            if (_meusConvites.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "Nenhum convite.",
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ..._meusConvites.map(
              (inv) => ListTile(
                dense: true,
                title: Text(
                  inv['game_name'],
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                subtitle: Text(
                  "De: ${inv['sender_name']}",
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                  ),
                  onPressed: () async {
                    await _entrarNoJogo(inv['game_id'].toString());
                    await _supabase
                        .from('invites')
                        .delete()
                        .eq('id', inv['id']);
                    _buscarConvites();
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirSala(Map<String, dynamic> game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    game['name'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.person_add_alt_1,
                    color: accentColor,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _abrirListaParaConvidar(game);
                  },
                ),
              ],
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _supabase
                    .from('participants')
                    .select()
                    .eq('game_id', game['id']),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return Center(
                      child: CircularProgressIndicator(color: accentColor),
                    );
                  final lista = snapshot.data ?? [];
                  bool euEstou = lista.any(
                    (p) => p['user_id'] == _supabase.auth.currentUser?.id,
                  );
                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          children: lista
                              .map(
                                (p) => ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  title: Text(
                                    p['user_name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!euEstou)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            minimumSize: const Size(double.infinity, 40),
                          ),
                          onPressed: () => _entrarNoJogo(
                            game['id'].toString(),
                          ).then((_) => Navigator.pop(context)),
                          child: const Text(
                            "CONFIRMAR PRESENÇA",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            minimumSize: const Size(double.infinity, 40),
                          ),
                          onPressed: () => _sairDoJogo(
                            game['id'].toString(),
                          ).then((_) => Navigator.pop(context)),
                          child: const Text(
                            "SAIR DA LISTA",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirListaParaConvidar(Map<String, dynamic> game) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "CONVIDAR JOGADORES",
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _supabase.from('profiles').select('id, username'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final lista = (snapshot.data ?? [])
                      .where((u) => u['id'] != _supabase.auth.currentUser?.id)
                      .toList();
                  return ListView.builder(
                    itemCount: lista.length,
                    itemBuilder: (context, i) => ListTile(
                      dense: true,
                      title: Text(
                        lista[i]['username'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      trailing: Icon(
                        Icons.send_rounded,
                        color: accentColor,
                        size: 18,
                      ),
                      onTap: () async {
                        await _supabase.from('invites').insert({
                          'game_id': game['id'],
                          'sender_id': _supabase.auth.currentUser!.id,
                          'receiver_id': lista[i]['id'],
                          'game_name': game['name'],
                          'sender_name': _meuUsername,
                        });
                        Navigator.pop(context);
                        _notificar("Convite enviado!", Colors.green);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
