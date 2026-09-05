import 'package:flutter/material.dart';

import 'package:jarvis_mobile/services/Jarvis_api.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.api,
    required this.onLogout,
  });

  final JarvisApi api;
  final VoidCallback onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  final List<String> _titles = [
    'Dashboard',
    'Conversas',
    'Memórias',
    'Configurações',
  ];

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await widget.api.logout();

    if (!mounted) {
      return;
    }

    widget.onLogout();
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();

      case 1:
        return _buildConversations();

      case 2:
        return _buildMemories();

      case 3:
        return _buildSettings();

      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bem-vindo ao J.A.R.V.I.S.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Central de comando do sistema.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          _buildStatusGrid(),
          const SizedBox(height: 32),
          _buildCommandCard(),
        ],
      ),
    );
  }

  Widget _buildStatusGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 700;

        final cards = [
          _buildStatusCard(
            icon: Icons.cloud_done_outlined,
            title: 'Backend',
            value: 'Online',
            description: 'Servidor conectado',
          ),
          _buildStatusCard(
            icon: Icons.memory_outlined,
            title: 'Memórias',
            value: 'Ativas',
            description: 'Sistema de memória disponível',
          ),
          _buildStatusCard(
            icon: Icons.psychology_outlined,
            title: 'Inteligência',
            value: 'Gemini',
            description: 'Motor de IA conectado',
          ),
        ];

        if (compact) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: 16,
                    ),
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: cards
              .map(
                (card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 16,
                    ),
                    child: card,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String value,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.cyanAccent,
            size: 30,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.smart_toy_outlined,
            color: Colors.cyanAccent,
            size: 34,
          ),
          const SizedBox(height: 18),
          const Text(
            'Central de Comando',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Acesse suas conversas e interaja diretamente '
            'com o J.A.R.V.I.S.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              _selectPage(1);
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Abrir conversas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversations() {
    return _SimplePage(
      icon: Icons.chat_outlined,
      title: 'Conversas',
      description:
          'Aqui ficarão suas conversas com o J.A.R.V.I.S.',
      child: FutureBuilder<List<dynamic>>(
        future: widget.api.getConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.only(top: 30),
              child: CircularProgressIndicator(
                color: Colors.cyanAccent,
              ),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'Não foi possível carregar as conversas.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'Nenhuma conversa encontrada.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: conversations.length,
            separatorBuilder: (context, index) {
              return const SizedBox(height: 10);
            },
            itemBuilder: (context, index) {
              final item = conversations[index];

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMemories() {
    return _SimplePage(
      icon: Icons.memory_outlined,
      title: 'Memórias',
      description:
          'Gerencie as informações que o J.A.R.V.I.S. armazenou.',
      child: FutureBuilder<List<dynamic>>(
        future: widget.api.getMemories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.only(top: 30),
              child: CircularProgressIndicator(
                color: Colors.cyanAccent,
              ),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'Não foi possível carregar as memórias.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            );
          }

          final memories = snapshot.data ?? [];

          if (memories.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'Nenhuma memória encontrada.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: memories.length,
            separatorBuilder: (context, index) {
              return const SizedBox(height: 10);
            },
            itemBuilder: (context, index) {
              final memory = memories[index];

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  memory.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSettings() {
    return _SimplePage(
      icon: Icons.settings_outlined,
      title: 'Configurações',
      description:
          'Configurações da conta e do sistema J.A.R.V.I.S.',
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.person_outline,
            title: 'Conta',
            subtitle: 'Gerenciar sua conta',
          ),
          const SizedBox(height: 10),
          _buildSettingTile(
            icon: Icons.palette_outlined,
            title: 'Aparência',
            subtitle: 'Tema e interface',
          ),
          const SizedBox(height: 10),
          _buildSettingTile(
            icon: Icons.record_voice_over_outlined,
            title: 'Voz',
            subtitle: 'Configurações de voz',
          ),
          const SizedBox(height: 10),
          _buildSettingTile(
            icon: Icons.security_outlined,
            title: 'Segurança',
            subtitle: 'Sessão e segurança',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.cyanAccent,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      child: Material(
        color: selected
            ? Colors.cyanAccent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _selectPage(index);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? Colors.cyanAccent
                      : Colors.white70,
                  size: 21,
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? Colors.cyanAccent
                            : Colors.white70,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A0F),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(
              milliseconds: 200,
            ),
            width: _sidebarExpanded ? 250 : 78,
            decoration: BoxDecoration(
              color: const Color(0xFF080F16),
              border: Border(
                right: BorderSide(
                  color: Colors.cyanAccent.withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.smart_toy_outlined,
                          color: Colors.cyanAccent,
                          size: 30,
                        ),
                        if (_sidebarExpanded) ...[
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'J.A.R.V.I.S.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildSidebarItem(
                    index: 0,
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                  ),
                  _buildSidebarItem(
                    index: 1,
                    icon: Icons.chat_outlined,
                    label: 'Conversas',
                  ),
                  _buildSidebarItem(
                    index: 2,
                    icon: Icons.memory_outlined,
                    label: 'Memórias',
                  ),
                  _buildSidebarItem(
                    index: 3,
                    icon: Icons.settings_outlined,
                    label: 'Configurações',
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _sidebarExpanded
                        ? 'Recolher menu'
                        : 'Expandir menu',
                    onPressed: () {
                      setState(() {
                        _sidebarExpanded =
                            !_sidebarExpanded;
                      });
                    },
                    icon: Icon(
                      _sidebarExpanded
                          ? Icons.chevron_left
                          : Icons.chevron_right,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070D13),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(
                            alpha: 0.05,
                          ),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _titles[_selectedIndex],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Online',
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: 0.55,
                            ),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          tooltip: 'Sair',
                          onPressed: _logout,
                          icon: const Icon(
                            Icons.logout_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _buildCurrentPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimplePage extends StatelessWidget {
  const _SimplePage({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.cyanAccent,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 30),
            child,
          ],
        ),
      ),
    );
  }
}