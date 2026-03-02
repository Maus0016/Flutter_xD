import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool loading = false;
  bool _senhaVisivel = false;

  // Paleta Dark Modern
  final Color backgroundDark = const Color(
    0xFF0F0F0F,
  ); // Sincronizado com a JogosPage
  final Color surfaceDark = const Color(
    0xFF1A1A1A,
  ); // Sincronizado com a JogosPage
  final Color accentColor = const Color(0xFF03DAC6);

  Future<void> cadastrar() async {
    FocusScope.of(context).unfocus();

    final nome = nomeController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      _notificar('Preencha todos os campos!', Colors.orange);
      return;
    }

    setState(() => loading = true);

    try {
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: senha,
        data: {'full_name': nome},
      );

      final user = res.user;

      if (user != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'username': nome,
          'is_admin': false,
        });

        if (!mounted) return;

        if (res.session == null) {
          _notificar('Cadastro realizado! Verifique seu e-mail.', accentColor);
        } else {
          _notificar('Bem-vindo, $nome!', Colors.greenAccent);
        }

        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      _notificar(e.message, Colors.redAccent);
    } catch (e) {
      _notificar('Erro ao realizar cadastro: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _notificar(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: accentColor),
      ),
      body: Center(
        // Centraliza tudo na tela
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 400,
          ), // Limita a largura para não "esparramar"
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 60, // Diminuído levemente
                  color: accentColor,
                ),
                const SizedBox(height: 15),
                const Text(
                  "NOVA CONTA",
                  style: TextStyle(
                    fontSize: 22, // Mais compacto
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                const Text(
                  "Junte-se à Risk Torurnament agora",
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 35),

                // Card de Formulário
                Container(
                  padding: const EdgeInsets.all(20), // Padding interno reduzido
                  decoration: BoxDecoration(
                    color: surfaceDark,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: nomeController,
                        label: "Nome Completo",
                        icon: Icons.person_outline,
                        capitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: emailController,
                        label: "E-mail",
                        icon: Icons.email_outlined,
                        type: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: senhaController,
                        label: "Senha",
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      const SizedBox(height: 30),

                      // Botão Principal
                      SizedBox(
                        width: double.infinity,
                        height: 48, // Altura mais elegante
                        child: ElevatedButton(
                          onPressed: loading ? null : cadastrar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "CRIAR CONTA",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: "Já possui uma conta? ",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: "Login",
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType type = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? !_senhaVisivel : false,
      keyboardType: type,
      textCapitalization: capitalization,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: Icon(icon, color: accentColor, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _senhaVisivel ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF0F0F0F), // Background interno dos campos
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1.2),
        ),
      ),
    );
  }
}
