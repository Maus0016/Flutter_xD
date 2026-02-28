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

  List<Map<String, dynamic>> _meusConvites = [];

  String _esporteSelecionado = 'Futebol';
  String _localSelecionado = 'Ginásio';
  String _horarioSelecionado = '09:00';
  DateTime _dataSelecionada = DateTime.now();

  final List<String> _esportes = ['Futebol', 'Vôlei', 'Basquete'];
  final List<String> _locais = [
    'Ginásio',
    'Campo 1',
    'Campo 2',
    'Quadra Poliesportiva',
  ];
  final List<String> _horarios = List.generate(
    14,
    (i) => '${(i + 9).toString().padLeft(2, '0')}:00',
  );

  Stream<List<Map<String, dynamic>>>? _gamesStream;

  // CORES DO SEU LOGIN
  final Color backgroundDark = const Color(0xFF0F0F0F);
  final Color surfaceDark = const Color(0xFF1A1A1A);
  final Color accentColor = const Color(0xFF03DAC6);

  @override
  void initState() {
    super.initState();
    _inicializarPagina();
  }

  Future<void> _inicializarPagina() async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      final user = _supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
        return;
      }

      final String? nomeAuth =
          user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
      final data = await _supabase
          .from('profiles')
          .select('username, is_admin')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isAdmin = data?['is_admin'] ?? false;
          _meuUsername =
              nomeAuth ?? data?['username'] ?? user.email ?? "Jogador";
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

    if (mounted) {
      setState(() {
        _meusConvites = List<Map<String, dynamic>>.from(data);
      });
    }
  }

  Future<void> _selecionarData() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final DateTime hoje = DateTime.now();
    final DateTime? colhida = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada.isBefore(hoje) ? hoje : _dataSelecionada,
      firstDate: hoje,
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              onPrimary: Colors.black,
              surface: surfaceDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (colhida != null && mounted) {
      setState(() => _dataSelecionada = colhida);
    }
  }

  void _abrirPainelConvites() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "MEUS CONVITES",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  if (_meusConvites.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        "Nenhum convite novo.",
                        style: TextStyle(color: Colors.white24),
                      ),
                    ),
                  ..._meusConvites.map(
                    (inv) => ListTile(
                      leading: Icon(Icons.mail_outline, color: accentColor),
                      title: Text(
                        inv['game_name'],
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "De: ${inv['sender_name']}",
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.greenAccent,
                            ),
                            onPressed: () async {
                              await _entrarNoJogo(inv['game_id'].toString());
                              await _supabase
                                  .from('invites')
                                  .delete()
                                  .eq('id', inv['id']);
                              await _buscarConvites();
                              if (mounted) Navigator.pop(context);
                              _notificar("Convite aceito!", Colors.greenAccent);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.cancel,
                              color: Colors.redAccent,
                            ),
                            onPressed: () async {
                              await _supabase
                                  .from('invites')
                                  .delete()
                                  .eq('id', inv['id']);
                              await _buscarConvites();
                              if (mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirListaParaConvidar(Map<String, dynamic> game) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                "CONVIDAR JOGADORES",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _supabase.from('profiles').select('id, username'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return Center(
                        child: CircularProgressIndicator(color: accentColor),
                      );
                    final usuarios = snapshot.data ?? [];
                    final meuId = _supabase.auth.currentUser?.id;
                    final outrosJogadores = usuarios
                        .where((u) => u['id'] != meuId)
                        .toList();
                    return ListView.builder(
                      itemCount: outrosJogadores.length,
                      itemBuilder: (context, i) {
                        final userRow = outrosJogadores[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Icon(Icons.person, color: accentColor),
                          ),
                          title: Text(
                            userRow['username'] ?? "Jogador",
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: Icon(Icons.send, color: accentColor),
                          onTap: () async {
                            try {
                              await _supabase.from('invites').insert({
                                'game_id': game['id'],
                                'sender_id': _supabase.auth.currentUser!.id,
                                'receiver_id': userRow['id'],
                                'game_name': game['name'],
                                'sender_name': _meuUsername,
                              });
                              if (mounted) Navigator.pop(context);
                              _notificar("Convite enviado!", accentColor);
                            } catch (e) {
                              _notificar("Erro ao enviar.", Colors.redAccent);
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _entrarNoJogo(String gameId) async {
    try {
      await _supabase.from('participants').insert({
        'game_id': gameId,
        'user_id': _supabase.auth.currentUser!.id,
        'user_name': _meuUsername,
      });
    } catch (e) {
      _notificar('Você já está na lista!', Colors.orangeAccent);
    }
  }

  void _abrirSala(Map<String, dynamic> game) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        final meuId = _supabase.auth.currentUser?.id;
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      game['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.person_add_alt_1, color: accentColor),
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
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return Center(
                        child: CircularProgressIndicator(color: accentColor),
                      );
                    final lista = snapshot.data ?? [];
                    bool euJaEstouNaLista = lista.any(
                      (p) => p['user_id'] == meuId,
                    );
                    return Column(
                      children: [
                        Expanded(
                          child: lista.isEmpty
                              ? const Center(
                                  child: Text(
                                    "Ninguém confirmou ainda.",
                                    style: TextStyle(color: Colors.white24),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: lista.length,
                                  itemBuilder: (context, i) {
                                    final isMe = lista[i]['user_id'] == meuId;
                                    return ListTile(
                                      leading: Icon(
                                        Icons.check_circle,
                                        color: isMe
                                            ? accentColor
                                            : Colors.greenAccent,
                                      ),
                                      title: Text(
                                        lista[i]['user_name'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 20),
                        if (!euJaEstouNaLista)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              minimumSize: const Size(double.infinity, 50),
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
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            onPressed: () => _sairDoJogo(
                              game['id'].toString(),
                            ).then((_) => Navigator.pop(context)),
                            child: const Text(
                              "SAIR DA LISTA",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sairDoJogo(String gameId) async {
    try {
      await _supabase.from('participants').delete().match({
        'game_id': gameId,
        'user_id': _supabase.auth.currentUser!.id,
      });
      _notificar('Você saiu da lista.', Colors.white24);
    } catch (e) {
      _notificar('Erro ao sair.', Colors.redAccent);
    }
  }

  Future<void> _salvarJogo() async {
    final nomeFinal =
        "$_esporteSelecionado - ${_dataSelecionada.day}/${_dataSelecionada.month} - $_horarioSelecionado";
    setState(() => _isLoading = true);
    try {
      await _supabase.from('games').insert({'name': nomeFinal});
      _notificar('Partida criada!', accentColor);
    } catch (e) {
      _notificar('Erro ao criar.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _notificar(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: cor));
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: backgroundDark,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: surfaceDark,
        elevation: 0,
        title: const Text(
          'Arena de Jogos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: accentColor),
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
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_meusConvites.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _supabase.auth.signOut().then(
              (_) => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _buscarConvites,
        color: accentColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Olá, $_meuUsername!",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              Text(
                "CRIAR NOVA PARTIDA",
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              _buildFormulario(),
              const SizedBox(height: 30),
              Text(
                "PARTIDAS ATIVAS",
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              _buildListaRealtime(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _buildDrop(
            "Esporte",
            Icons.sports_soccer,
            _esporteSelecionado,
            _esportes,
            (v) => setState(() => _esporteSelecionado = v!),
          ),
          const SizedBox(height: 10),
          _buildDrop(
            "Local",
            Icons.location_on,
            _localSelecionado,
            _locais,
            (v) => setState(() => _localSelecionado = v!),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.calendar_today, color: accentColor),
            title: Text(
              "Data: ${_dataSelecionada.day}/${_dataSelecionada.month}",
              style: const TextStyle(color: Colors.white),
            ),
            trailing: const Icon(Icons.edit, size: 16, color: Colors.white24),
            onTap: _selecionarData,
          ),
          _buildDrop(
            "Horário",
            Icons.access_time,
            _horarioSelecionado,
            _horarios,
            (v) => setState(() => _horarioSelecionado = v!),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _salvarJogo,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text(
                    "PUBLICAR JOGO",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrop(
    String label,
    IconData icon,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: surfaceDark,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: accentColor),
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
          return const Center(child: CircularProgressIndicator());
        final games = snapshot.data!;
        if (games.isEmpty)
          return const Center(
            child: Text(
              "Nenhuma partida ativa.",
              style: TextStyle(color: Colors.white24),
            ),
          );
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final g = games[index];
            return Card(
              color: surfaceDark,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white10),
              ),
              child: ListTile(
                onTap: () => _abrirSala(g),
                leading: CircleAvatar(
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.sports_soccer, color: accentColor),
                ),
                title: Text(
                  g['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: const Text(
                  "Toque para ver detalhes",
                  style: TextStyle(color: Colors.white38),
                ),
                trailing: _isAdmin
                    ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () =>
                            _supabase.from('games').delete().eq('id', g['id']),
                      )
                    : Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: accentColor,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
