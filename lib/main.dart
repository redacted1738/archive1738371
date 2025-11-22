import 'dart:convert';
import 'package:flutter/material.dart';

void main() {
  runApp(const NexusApp());
}

/// ROOT APP

class NexusApp extends StatelessWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nexus Archive',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF111317),
        cardColor: const Color(0xFF181B20),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181B20),
          elevation: 0,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

/// DATA MODELS + STORES

class NexusUser {
  final String id;
  final String email;
  String username;
  String password; // plain-text for prototype only
  int level; // 0–6
  final bool isOwner;
  String avatarUrl;
  DateTime? dob;
  final DateTime createdAt;
  int xp; // XP for leveling up

  /// Last time this user viewed a given channel (channelId -> DateTime)
  Map<String, DateTime> lastReadChannels;

  /// Last time this user viewed a DM with another user
  /// (other user's email lowercased -> DateTime)
  Map<String, DateTime> lastReadDms;

  NexusUser({
    required this.id,
    required this.email,
    required this.username,
    required this.password,
    required this.level,
    required this.isOwner,
    this.avatarUrl = '',
    this.dob,
    this.xp = 0,
    DateTime? createdAt,
    Map<String, DateTime>? lastReadChannels,
    Map<String, DateTime>? lastReadDms,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastReadChannels = lastReadChannels ?? {},
        lastReadDms = lastReadDms ?? {};
}

class NexusEntry {
  final String id;
  String title;
  String content;
  String category;
  String createdByEmail;
  DateTime createdAt;
  int minLevel; // visible from this level up
  bool pinned;
  bool system;
  bool isCommunity; // community board type
  List<String> attachmentUrls;
  String? spreadsheetName;
  String? spreadsheetCsv;

  NexusEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.createdByEmail,
    required this.createdAt,
    required this.minLevel,
    this.pinned = false,
    this.system = false,
    this.isCommunity = false,
    List<String>? attachmentUrls,
    this.spreadsheetName,
    this.spreadsheetCsv,
  }) : attachmentUrls = attachmentUrls ?? [];
}

class NexusComment {
  final String id;
  final String entryId;
  final String authorEmail;
  final String text;
  final DateTime createdAt;

  NexusComment({
    required this.id,
    required this.entryId,
    required this.authorEmail,
    required this.text,
    required this.createdAt,
  });
}

/// Community items (for community entries)

class CommunityItem {
  final String id;
  final String entryId;
  final String addedByEmail;
  final String label;
  final String url;
  final DateTime createdAt;

  CommunityItem({
    required this.id,
    required this.entryId,
    required this.addedByEmail,
    required this.label,
    required this.url,
    required this.createdAt,
  });
}

/// CHAT MODELS

enum ChatMessageType { channel, direct }

class ChatChannel {
  final String id;
  final String name;
  final String description;
  final int minLevel; // minimum level to see this channel
  final bool readOnly;

  ChatChannel({
    required this.id,
    required this.name,
    required this.description,
    this.minLevel = 0,
    this.readOnly = false,
  });
}

/// Global chat message

class ChatMessage {
  final String id;
  final ChatMessageType type;
  final String authorEmail;
  final String text;
  final DateTime createdAt;

  // For channel messages
  final String? channelId;

  // For DMs
  final String? recipientEmail;

  ChatMessage({
    required this.id,
    required this.type,
    required this.authorEmail,
    required this.text,
    required this.createdAt,
    this.channelId,
    this.recipientEmail,
  });
}

/// Global system state (lockdown, self-destruct)

class SystemStateStore {
  SystemStateStore._internal();

  static final SystemStateStore instance = SystemStateStore._internal();

  bool lockdown = false;
  bool selfDestructArmed = false;
}

/// USER STORE

class UserStore {
  UserStore._internal() {
    // bootstrap owner account
    final owner = NexusUser(
      id: 'owner',
      email: 'admin@nexus.local',
      username: 'Owner',
      password: 'owner', // demo only
      level: 6,
      isOwner: true,
      avatarUrl: '',
      xp: 99999,
      lastReadChannels: {},
      lastReadDms: {},
    );
    _users.add(owner);
    _currentUser = owner;
  }

  static final UserStore instance = UserStore._internal();

  // XP thresholds by level
  static const Map<int, int> levelThresholds = {
    1: 100,
    2: 300,
    3: 700,
    4: 1500,
  };

  final List<NexusUser> _users = [];
  NexusUser? _currentUser;

  List<NexusUser> get users => List.unmodifiable(_users);
  NexusUser? get currentUser => _currentUser;

  NexusUser? getUser(String email) {
    try {
      return _users.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  bool emailTaken(String email) {
    return _users.any(
      (u) => u.email.toLowerCase() == email.toLowerCase(),
    );
  }

  NexusUser? login(String email, String password) {
    try {
      final user = _users.firstWhere(
        (u) =>
            u.email.toLowerCase() == email.toLowerCase() &&
            u.password == password,
      );
      _currentUser = user;
      return user;
    } catch (_) {
      _currentUser = null;
      return null;
    }
  }

  NexusUser register({
    required String email,
    required String password,
    required String username,
  }) {
    final newUser = NexusUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      username: username,
      password: password,
      level: 0, // default Level 0
      isOwner: false,
      lastReadChannels: {},
      lastReadDms: {},
    );
    _users.add(newUser);
    _currentUser = newUser;
    return newUser;
  }

  void logout() {
    _currentUser = null;
  }

  void updateUser(NexusUser user) {
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
    }
    if (_currentUser?.id == user.id) {
      _currentUser = user;
    }
  }

  // manual level set (e.g., for Level 5)
  void setUserLevel(NexusUser target, int newLevel) {
    if (target.isOwner) return; // Owner always level 6
    final safeLevel = newLevel.clamp(0, 5);
    target.level = safeLevel;
    updateUser(target);
  }

  // XP system
  void addXp(NexusUser user, int amount) {
    if (amount <= 0) return;
    user.xp += amount;
    _recomputeLevelFromXp(user);
    updateUser(user);
  }

  void _recomputeLevelFromXp(NexusUser user) {
    if (user.isOwner) {
      user.level = 6;
      return;
    }
    // If already manually promoted to 5, do not override
    if (user.level >= 5) return;

    int newLevel = user.level;
    levelThresholds.forEach((lvl, neededXp) {
      if (user.xp >= neededXp && lvl > newLevel) {
        newLevel = lvl;
      }
    });

    user.level = newLevel.clamp(0, 4);
  }
}

/// ENTRY STORE + COMMENTS

class EntryStore {
  EntryStore._internal() {
    final now = DateTime.now();
    _entries.addAll([
      NexusEntry(
        id: 'system_welcome',
        title: 'Welcome to the Archive',
        content:
            'Welcome to the Nexus Archive.\n\n'
            'Everything here is logged, versioned, and tied to your clearance level.\n'
            'Treat this like a shared brain: add what you know, and read what others have left behind.',
        category: 'System',
        createdByEmail: 'admin@nexus.local',
        createdAt: now,
        minLevel: 0,
        system: true,
        pinned: true,
      ),
      NexusEntry(
        id: 'system_mission',
        title: 'Mission Statement',
        content:
            'Our mission is to preserve knowledge, track operations, and keep a persistent record of the Nexus Initiative.\n\n'
            'Use this Archive to:\n'
            '• Record events and decisions\n'
            '• Store references, links, and files\n'
            '• Build a living history of the project',
        category: 'System',
        createdByEmail: 'admin@nexus.local',
        createdAt: now,
        minLevel: 0,
        system: true,
        pinned: true,
      ),
      NexusEntry(
        id: 'system_rules',
        title: 'Archive Rules',
        content:
            '1. Do not upload anything illegal or unsafe.\n'
            '2. Assume everything you write here will be read by higher levels.\n'
            '3. Clearly mark speculation vs. confirmed facts.\n'
            '4. Use [[REDACT]] ... [[/REDACT]] to hide sensitive segments.\n'
            '5. System pages cannot be edited or deleted.',
        category: 'System',
        createdByEmail: 'admin@nexus.local',
        createdAt: now,
        minLevel: 0,
        system: true,
        pinned: true,
      ),
    ]);
  }

  static final EntryStore instance = EntryStore._internal();

  final List<NexusEntry> _entries = [];
  final List<NexusComment> _comments = [];

  List<NexusEntry> get entries => List.unmodifiable(_entries);
  List<NexusComment> get allComments => List.unmodifiable(_comments);

  NexusEntry? getById(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<NexusEntry> entriesForLevel(int level) {
    final visible = _entries.where((e) => e.minLevel <= level).toList();
    visible.sort((a, b) {
      if (a.pinned != b.pinned) {
        return b.pinned ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return visible;
  }

  void addEntry(NexusEntry entry) {
    _entries.add(entry);
  }

  void updateEntry(NexusEntry entry) {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index != -1) {
      _entries[index] = entry;
    }
  }

  void deleteEntry(NexusEntry entry) {
    if (entry.system) return;
    _entries.removeWhere((e) => e.id == entry.id);
    _comments.removeWhere((c) => c.entryId == entry.id);
    CommunityStore.instance.removeItemsForEntry(entry.id);
  }

  void addComment(NexusComment c) {
    _comments.add(c);
  }

  List<NexusComment> commentsForEntry(String entryId) {
    return _comments.where((c) => c.entryId == entryId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
}

/// COMMUNITY STORE

class CommunityStore {
  CommunityStore._internal();

  static final CommunityStore instance = CommunityStore._internal();

  final List<CommunityItem> _items = [];

  List<CommunityItem> itemsForEntry(String entryId) {
    return _items.where((i) => i.entryId == entryId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<CommunityItem> get allItems => List.unmodifiable(_items);

  void addItem(CommunityItem item) {
    _items.add(item);
  }

  void removeItemsForEntry(String entryId) {
    _items.removeWhere((i) => i.entryId == entryId);
  }
}

/// CHAT STORE

class ChatStore {
  ChatStore._internal() {
    // default channels
    _channels.addAll([
      ChatChannel(
        id: 'global',
        name: '#global',
        description: 'General discussion for everyone.',
        minLevel: 0,
      ),
      ChatChannel(
        id: 'field',
        name: '#field-notes',
        description: 'Field logs, ops notes, quick observations.',
        minLevel: 1,
      ),
      ChatChannel(
        id: 'staff',
        name: '#staff',
        description: 'High-level planning (Level 4+).',
        minLevel: 4,
      ),
      ChatChannel(
        id: 'council',
        name: '#council',
        description: 'O5 / Level 5+ coordination.',
        minLevel: 5,
      ),
    ]);
  }

  static final ChatStore instance = ChatStore._internal();

  final List<ChatChannel> _channels = [];
  final List<ChatMessage> _messages = [];

  List<ChatChannel> get channels => List.unmodifiable(_channels);
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  List<ChatChannel> channelsForUser(NexusUser user) {
    return _channels.where((c) => user.level >= c.minLevel).toList();
  }

  void addChannelMessage({
    required String channelId,
    required String authorEmail,
    required String text,
  }) {
    _messages.add(
      ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        type: ChatMessageType.channel,
        authorEmail: authorEmail,
        text: text,
        createdAt: DateTime.now(),
        channelId: channelId,
      ),
    );
  }

  void addDirectMessage({
    required String fromEmail,
    required String toEmail,
    required String text,
  }) {
    _messages.add(
      ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        type: ChatMessageType.direct,
        authorEmail: fromEmail,
        text: text,
        createdAt: DateTime.now(),
        recipientEmail: toEmail,
      ),
    );
  }

  List<ChatMessage> messagesForChannel(String channelId) {
    final list = _messages
        .where(
          (m) =>
              m.type == ChatMessageType.channel &&
              m.channelId == channelId,
        )
        .toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  List<ChatMessage> messagesForDirect(String emailA, String emailB) {
    final a = emailA.toLowerCase();
    final b = emailB.toLowerCase();
    final list = _messages.where((m) {
      if (m.type != ChatMessageType.direct) return false;
      final sender = m.authorEmail.toLowerCase();
      final recipient = (m.recipientEmail ?? '').toLowerCase();
      return (sender == a && recipient == b) ||
          (sender == b && recipient == a);
    }).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  int unreadForChannel(NexusUser user, ChatChannel channel) {
    final last = user.lastReadChannels[channel.id] ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return messagesForChannel(channel.id)
        .where(
          (m) =>
              m.createdAt.isAfter(last) &&
              m.authorEmail.toLowerCase() !=
                  user.email.toLowerCase(),
        )
        .length;
  }

  int unreadForDm(NexusUser user, NexusUser other) {
    final key = other.email.toLowerCase();
    final last = user.lastReadDms[key] ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final msgs = messagesForDirect(user.email, other.email);
    return msgs
        .where(
          (m) =>
              m.createdAt.isAfter(last) &&
              m.authorEmail.toLowerCase() !=
                  user.email.toLowerCase(),
        )
        .length;
  }

  int totalUnreadForUser(NexusUser user) {
    var total = 0;

    for (final c in channelsForUser(user)) {
      total += unreadForChannel(user, c);
    }

    for (final u in UserStore.instance.users) {
      if (u.email.toLowerCase() == user.email.toLowerCase()) continue;
      total += unreadForDm(user, u);
    }

    return total;
  }

  void markAllReadForUser(NexusUser user) {
    final now = DateTime.now();

    for (final c in _channels) {
      user.lastReadChannels[c.id] = now;
    }

    for (final u in UserStore.instance.users) {
      if (u.email.toLowerCase() == user.email.toLowerCase()) continue;
      user.lastReadDms[u.email.toLowerCase()] = now;
    }

    UserStore.instance.updateUser(user);
  }
}

/// LOGIN / AUTH

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _obscure = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _error = null;
    });

    if (_isLogin) {
      final user = UserStore.instance.login(email, password);
      if (user == null) {
        setState(() {
          _error = 'Invalid email or password.';
        });
        return;
      }
    } else {
      if (UserStore.instance.emailTaken(email)) {
        setState(() {
          _error = 'That email is already registered.';
        });
        return;
      }
      final username =
          _usernameController.text.trim().isEmpty
              ? email
              : _usernameController.text.trim();
      UserStore.instance.register(
        email: email,
        password: password,
        username: username,
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ShellScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nexus Login',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email required';
                            }
                            if (!v.contains('@')) {
                              return 'Invalid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon:
                                const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () {
                                setState(() {
                                  _obscure = !_obscure;
                                });
                              },
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Password required';
                            }
                            if (v.length < 4) {
                              return 'At least 4 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submit,
                      child: Text(_isLogin ? 'Log In' : 'Sign Up'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _error = null;
                      });
                    },
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign up"
                          : 'Already registered? Log in',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Default Owner:\nadmin@nexus.local / owner',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SHELL (after login)

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = UserStore.instance.currentUser!;
    final system = SystemStateStore.instance;
    final unreadChatCount = ChatStore.instance.totalUnreadForUser(user);

    final pages = <Widget>[
      const ArchiveHomeScreen(),
      const ChatScreen(),
      if (user.level >= 4) const ManageUsersScreen(),
      if (user.level >= 5) const AdminControlScreen(),
      if (user.level >= 6) const NexusScreen(),
      ProfileScreen(user: user),
    ];

    final titles = <String>[
      'Archive',
      'Chat',
      if (user.level >= 4) 'Manage Users',
      if (user.level >= 5) 'Control',
      if (user.level >= 6) 'Nexus',
      'Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Nexus Archive – ${titles[_index]}'),
        bottom: system.lockdown
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Container(
                  width: double.infinity,
                  color: Colors.red.withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: const Text(
                    'LOCKDOWN ACTIVE – archive is in restricted mode',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () {
              UserStore.instance.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;

            // When user taps Chat tab, clear all unread
            if (i == 1) {
              final current = UserStore.instance.currentUser;
              if (current != null) {
                ChatStore.instance.markAllReadForUser(current);
              }
            }
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'Archive',
          ),
          NavigationDestination(
            icon: _NavIconWithDot(
              iconData: Icons.chat_outlined,
              showDot: unreadChatCount > 0,
            ),
            selectedIcon: _NavIconWithDot(
              iconData: Icons.chat,
              showDot: unreadChatCount > 0,
            ),
            label: 'Chat',
          ),
          if (user.level >= 4)
            const NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Users',
            ),
          if (user.level >= 5)
            const NavigationDestination(
              icon: Icon(Icons.security_outlined),
              selectedIcon: Icon(Icons.security),
              label: 'Control',
            ),
          if (user.level >= 6)
            const NavigationDestination(
              icon: Icon(Icons.memory_outlined),
              selectedIcon: Icon(Icons.memory),
              label: 'Nexus',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _NavIconWithDot extends StatelessWidget {
  final IconData iconData;
  final bool showDot;

  const _NavIconWithDot({
    required this.iconData,
    required this.showDot,
  });

  @override
  Widget build(BuildContext context) {
    if (!showDot) {
      return Icon(iconData);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(iconData),
        Positioned(
          right: -1,
          top: -1,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

/// ARCHIVE HOME

class ArchiveHomeScreen extends StatefulWidget {
  const ArchiveHomeScreen({super.key});

  @override
  State<ArchiveHomeScreen> createState() =>
      _ArchiveHomeScreenState();
}

class _ArchiveHomeScreenState extends State<ArchiveHomeScreen> {
  String _query = '';
  String _categoryFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final user = UserStore.instance.currentUser!;
    final entries = EntryStore.instance.entriesForLevel(user.level);
    final system = SystemStateStore.instance;

    final filtered = entries.where((e) {
      if (_categoryFilter != 'All' &&
          e.category.toLowerCase() !=
              _categoryFilter.toLowerCase()) {
        return false;
      }
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return e.title.toLowerCase().contains(q) ||
          e.content.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.createdByEmail.toLowerCase().contains(q);
    }).toList();

    final categories = <String>{
      'All',
      ...entries.map((e) => e.category),
    }.toList();

    return Scaffold(
      body: Column(
        children: [
          if (system.selfDestructArmed)
            Container(
              width: double.infinity,
              color: Colors.deepOrange.withOpacity(0.95),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              child: const Text(
                'SELF-DESTRUCT SYSTEM ARMED – this is a simulated state only.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search entries',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _query = v;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final selected = cat == _categoryFilter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _categoryFilter = cat;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No entries yet. Create the first one.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      final creator =
                          UserStore.instance.getUser(
                              entry.createdByEmail);
                      final label =
                          creator?.username.isNotEmpty == true
                              ? creator!.username
                              : entry.createdByEmail;

                      return Card(
                        margin:
                            const EdgeInsets.only(bottom: 12.0),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EntryDetailScreen(
                                  entryId: entry.id,
                                ),
                              ),
                            ).then((_) {
                              setState(() {});
                            });
                          },
                          leading: Icon(
                            entry.system
                                ? Icons.workspace_premium
                                : (entry.isCommunity
                                    ? Icons.diversity_3_outlined
                                    : Icons.description_outlined),
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(entry.title)),
                              if (entry.isCommunity)
                                const Padding(
                                  padding:
                                      EdgeInsets.only(left: 4.0),
                                  child: Icon(
                                    Icons.people,
                                    size: 16,
                                  ),
                                ),
                              if (entry.pinned)
                                const Icon(
                                  Icons.push_pin,
                                  size: 18,
                                ),
                            ],
                          ),
                          subtitle: Text(
                            '${entry.category} • '
                            'Level ${entry.minLevel}+ • '
                            '$label',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EditEntryScreen(),
            ),
          ).then((_) {
            setState(() {});
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('New entry'),
      ),
    );
  }
}

/// ENTRY DETAIL (with image + community previews)

class EntryDetailScreen extends StatefulWidget {
  final String entryId;

  const EntryDetailScreen({super.key, required this.entryId});

  @override
  State<EntryDetailScreen> createState() =>
      _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  final TextEditingController _commentController =
      TextEditingController();

  // Community item fields
  final TextEditingController _itemLabelController =
      TextEditingController();
  final TextEditingController _itemUrlController =
      TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    _itemLabelController.dispose();
    _itemUrlController.dispose();
    super.dispose();
  }

  bool _canEditOrDelete(NexusUser me, NexusEntry entry) {
    final isCreator =
        me.email.toLowerCase() ==
            entry.createdByEmail.toLowerCase();
    final isAdmin = me.level >= 4;
    return !entry.system && (isCreator || isAdmin);
  }

  List<TextSpan> _buildRedactedSpans(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(
      r'\[\[REDACT\]\](.*?)\[\[\/REDACT\]\]',
      dotAll: true,
    );

    int lastIndex = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
          ),
        );
      }
      final inner = match.group(1) ?? '';
      final redacted = '█' * (inner.length.clamp(4, 80));
      spans.add(
        TextSpan(
          text: redacted,
          style: const TextStyle(
            backgroundColor: Colors.black,
            color: Colors.black,
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
        ),
      );
    }

    return spans;
  }

  String _displayForAttachment(String url) {
    final trimmed = url.trim();

    if (trimmed.startsWith('data:')) {
      final mimePart =
          trimmed.split(';').first.replaceFirst('data:', '');
      return 'Inline ${mimePart.isEmpty ? "data" : mimePart}';
    }

    if (trimmed.length <= 60) return trimmed;
    return '${trimmed.substring(0, 57)}...';
  }

  // image preview (contain)
  Widget _buildImagePreview(String url) {
    final trimmed = url.trim();

    try {
      // data:image/jpeg;base64,....
      if (trimmed.startsWith('data:image')) {
        final parts = trimmed.split(',');
        if (parts.length == 2) {
          final base64Str = parts[1];
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
          );
        }
      }

      // Raw base64 without data: prefix (e.g. starts with /9j/...)
      if (!trimmed.startsWith('http') &&
          !trimmed.startsWith('www.') &&
          trimmed.length > 100) {
        final bytes = base64Decode(trimmed);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
        );
      }

      // Normal URL
      return Image.network(
        trimmed,
        fit: BoxFit.contain,
      );
    } catch (_) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Failed to load image',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }
  }

  void _deleteEntry(NexusEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text(
          'This will permanently remove this entry, its comments, and any community items.\n\n'
          'System entries cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      EntryStore.instance.deleteEntry(entry);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted')),
      );
    }
  }

  void _addComment(NexusEntry entry, NexusUser user) {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final c = NexusComment(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      entryId: entry.id,
      authorEmail: user.email,
      text: text,
      createdAt: DateTime.now(),
    );

    EntryStore.instance.addComment(c);
    _commentController.clear();

    setState(() {});
  }

  void _addCommunityItem(NexusEntry entry, NexusUser user) {
    final label = _itemLabelController.text.trim();
    final url = _itemUrlController.text.trim();

    if (url.isEmpty) return;

    final item = CommunityItem(
      id: 'citem_${DateTime.now().millisecondsSinceEpoch}',
      entryId: entry.id,
      addedByEmail: user.email,
      label: label.isEmpty ? url : label,
      url: url,
      createdAt: DateTime.now(),
    );

    CommunityStore.instance.addItem(item);
    _itemLabelController.clear();
    _itemUrlController.clear();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entry = EntryStore.instance.getById(widget.entryId);
    final user = UserStore.instance.currentUser;

    if (entry == null || user == null) {
      Future.microtask(() {
        Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final creator =
        UserStore.instance.getUser(entry.createdByEmail);
    final creatorLabel = creator?.username.isNotEmpty == true
        ? creator!.username
        : entry.createdByEmail;

    final comments =
        EntryStore.instance.commentsForEntry(entry.id).reversed.toList();
    final canEditDelete = _canEditOrDelete(user, entry);
    final canPin = user.level >= 4;

    final communityItems =
        CommunityStore.instance.itemsForEntry(entry.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title),
        actions: [
          if (canEditDelete)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit entry',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditEntryScreen(entry: entry),
                  ),
                ).then((_) {
                  setState(() {});
                });
              },
            ),
          if (canEditDelete)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete entry',
              onPressed: () => _deleteEntry(entry),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // META
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.folder, size: 16),
                        label: Text(entry.category),
                      ),
                      Chip(
                        avatar: const Icon(Icons.visibility, size: 16),
                        label: Text('Level ${entry.minLevel}+'),
                      ),
                      if (entry.system)
                        Chip(
                          avatar: const Icon(
                            Icons.workspace_premium,
                            size: 16,
                            color: Colors.amber,
                          ),
                          label:
                              const Text('System / Permanent'),
                          backgroundColor:
                              Colors.amber.withOpacity(0.1),
                        )
                      else if (entry.isCommunity)
                        Chip(
                          avatar: const Icon(
                            Icons.people,
                            size: 16,
                          ),
                          label: const Text('Community entry'),
                          backgroundColor:
                              Colors.teal.withOpacity(0.1),
                        )
                      else if (entry.pinned)
                        Chip(
                          avatar: const Icon(Icons.push_pin,
                              size: 16),
                          label: const Text('Pinned'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Created by $creatorLabel',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Created at ${entry.createdAt}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!entry.system && canPin)
                    Row(
                      children: [
                        const Text('Pinned for all viewers'),
                        const SizedBox(width: 8),
                        Switch(
                          value: entry.pinned,
                          onChanged: (v) {
                            setState(() {
                              entry.pinned = v;
                              EntryStore.instance
                                  .updateEntry(entry);
                            });
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // CONTENT
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Content',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Use [[REDACT]]text[[/REDACT]] to black out sections.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText.rich(
                    TextSpan(
                      children: _buildRedactedSpans(entry.content),
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),

          // COMMUNITY SECTION
          if (entry.isCommunity) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Community Items',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Anyone with access can add links / items. '
                      'Good for shared game lists, resources, etc.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (communityItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'No items yet. Add the first one.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        itemCount: communityItems.length,
                        itemBuilder: (context, index) {
                          final item = communityItems[index];
                          final by =
                              UserStore.instance.getUser(
                                      item.addedByEmail)
                                  ?.username;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.link),
                            title: Text(item.label),
                            subtitle: Text(
                              '${item.url}\nAdded by ${by ?? item.addedByEmail}',
                              style:
                                  const TextStyle(fontSize: 11),
                            ),
                            onTap: () {
                              // In a real app, you'd launch the URL.
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _itemLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Label (optional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _itemUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL or identifier',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () =>
                            _addCommunityItem(entry, user),
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ATTACHMENTS
          if (entry.attachmentUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attachments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...entry.attachmentUrls.map((url) {
                      final lower = url.toLowerCase();
                      final isImage =
                          lower.endsWith('.png') ||
                              lower.endsWith('.jpg') ||
                              lower.endsWith('.jpeg') ||
                              lower.endsWith('.gif') ||
                              lower.endsWith('.webp') ||
                              url.startsWith('data:image');

                      if (!isImage) {
                        // Non-image: just show a simple row
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.attach_file),
                          title: Text(
                            _displayForAttachment(url),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: const Text(
                            'File / Link',
                            style: TextStyle(fontSize: 12),
                          ),
                        );
                      }

                      // Image: show label + preview
                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.image_outlined,
                            ),
                            title: Text(
                              _displayForAttachment(url),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                            subtitle: const Text(
                              'Image',
                              style:
                                  TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(8),
                            child: SizedBox(
                              height: 260,
                              width: double.infinity,
                              child: _buildImagePreview(url),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],

          // SPREADSHEET
          if (entry.spreadsheetName != null &&
              entry.spreadsheetName!.isNotEmpty &&
              entry.spreadsheetCsv != null &&
              entry.spreadsheetCsv!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spreadsheet: ${entry.spreadsheetName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSpreadsheetTable(
                      entry.spreadsheetCsv!,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // COMMENTS
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (comments.isEmpty)
                    const Padding(
                      padding:
                          EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'No comments yet.',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        final cu = UserStore.instance
                            .getUser(c.authorEmail);
                        final label =
                            cu?.username.isNotEmpty == true
                                ? cu!.username
                                : c.authorEmail;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.comment,
                            size: 18,
                          ),
                          title: Text(label),
                          subtitle: Text(
                            '${c.text}\n${c.createdAt}',
                            style: const TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      labelText: 'Add a comment',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () =>
                            _addComment(entry, user),
                      ),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetTable(String csv) {
    final rows = csv
        .split('\n')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .map((r) => r.split(',').map((v) => v.trim()).toList())
        .toList();

    if (rows.isEmpty) {
      return const Text(
        'Spreadsheet is empty or invalid CSV.',
        style: TextStyle(color: Colors.grey),
      );
    }

    final maxCols = rows
        .map((r) => r.length)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: Colors.grey),
        defaultVerticalAlignment:
            TableCellVerticalAlignment.middle,
        children: rows.map((row) {
          final filledRow = [
            ...row,
            ...List.filled(maxCols - row.length, ''),
          ];
          return TableRow(
            children: filledRow
                .map(
                  (cell) => Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      cell,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
          );
        }).toList(),
      ),
    );
  }
}

/// EDIT / CREATE ENTRY (with community toggle + XP on create)

class EditEntryScreen extends StatefulWidget {
  final NexusEntry? entry;

  const EditEntryScreen({super.key, this.entry});

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _categoryController;
  late TextEditingController _attachmentsController;
  late TextEditingController _spreadsheetNameController;
  late TextEditingController _spreadsheetCsvController;
  int _minLevel = 0;
  bool _pinned = false;
  bool _isCommunity = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _titleController =
        TextEditingController(text: e?.title ?? '');
    _contentController =
        TextEditingController(text: e?.content ?? '');
    _categoryController =
        TextEditingController(text: e?.category ?? 'General');
    _attachmentsController = TextEditingController(
      text: e?.attachmentUrls.join('\n') ?? '',
    );
    _spreadsheetNameController = TextEditingController(
      text: e?.spreadsheetName ?? '',
    );
    _spreadsheetCsvController = TextEditingController(
      text: e?.spreadsheetCsv ?? '',
    );
    _minLevel = e?.minLevel ?? 0;
    _pinned = e?.pinned ?? false;
    _isCommunity = e?.isCommunity ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    _attachmentsController.dispose();
    _spreadsheetNameController.dispose();
    _spreadsheetCsvController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final user = UserStore.instance.currentUser!;
    final attachments = _attachmentsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final isNew = widget.entry == null;
    NexusEntry entry;

    if (isNew) {
      entry = NexusEntry(
        id: 'entry_${DateTime.now().millisecondsSinceEpoch}',
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _categoryController.text.trim(),
        createdByEmail: user.email,
        createdAt: DateTime.now(),
        minLevel: _minLevel,
        pinned: _pinned && user.level >= 4,
        system: false,
        isCommunity: _isCommunity,
        attachmentUrls: attachments,
        spreadsheetName:
            _spreadsheetNameController.text.trim().isEmpty
                ? null
                : _spreadsheetNameController.text.trim(),
        spreadsheetCsv:
            _spreadsheetCsvController.text.trim().isEmpty
                ? null
                : _spreadsheetCsvController.text.trim(),
      );
      EntryStore.instance.addEntry(entry);

      // XP reward for creating a new entry
      final content = _contentController.text.trim();
      int wordCount = 0;
      if (content.isNotEmpty) {
        wordCount =
            content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      }
      final attachmentCount = attachments.length;
      int xpGain = (wordCount / 10).floor() +
          attachmentCount * 5;
      if (xpGain < 1) xpGain = 1;
      UserStore.instance.addXp(user, xpGain);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Entry created. Gained $xpGain XP.'),
        ),
      );
    } else {
      entry = widget.entry!;
      entry.title = _titleController.text.trim();
      entry.content = _contentController.text.trim();
      entry.category = _categoryController.text.trim();
      entry.minLevel = _minLevel;
      entry.pinned = _pinned && user.level >= 4;
      entry.isCommunity = _isCommunity;
      entry.attachmentUrls = attachments;
      entry.spreadsheetName =
          _spreadsheetNameController.text.trim().isEmpty
              ? null
              : _spreadsheetNameController.text.trim();
      entry.spreadsheetCsv =
          _spreadsheetCsvController.text.trim().isEmpty
              ? null
              : _spreadsheetCsvController.text.trim();
      EntryStore.instance.updateEntry(entry);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = UserStore.instance.currentUser!;
    final isEditing = widget.entry != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Entry' : 'New Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration:
                    const InputDecoration(labelText: 'Title'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Title required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryController,
                decoration:
                    const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  alignLabelWithHint: true,
                  helperText:
                      'Use [[REDACT]]secret[[/REDACT]] to black out segments.',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Content required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Visible from Level'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _minLevel,
                    items: List.generate(
                      6,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text('$i+'),
                      ),
                    ),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _minLevel = v;
                      });
                    },
                  ),
                  const Spacer(),
                  if (user.level >= 4)
                    Row(
                      children: [
                        const Text('Pinned'),
                        Switch(
                          value: _pinned,
                          onChanged: (v) {
                            setState(() {
                              _pinned = v;
                            });
                          },
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Community entry'),
                subtitle: const Text(
                  'Anyone with access can add shared items (links, games, resources) to this entry.',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isCommunity,
                onChanged: (v) {
                  setState(() {
                    _isCommunity = v;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _attachmentsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText:
                      'Attachments (one URL or base64 / data URI per line)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Spreadsheet (optional)'),
                children: [
                  TextFormField(
                    controller: _spreadsheetNameController,
                    decoration: const InputDecoration(
                      labelText: 'Spreadsheet name',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _spreadsheetCsvController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'CSV data',
                      alignLabelWithHint: true,
                      helperText: 'Comma-separated rows. Example:\n'
                          'Name,Value\nA,1\nB,2',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(isEditing ? 'Save changes' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// MANAGE USERS

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() =>
      _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  @override
  Widget build(BuildContext context) {
    final me = UserStore.instance.currentUser!;
    final users = UserStore.instance.users;

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final u = users[index];
          final canModify = me.level >= 5 && !u.isOwner;

          return Card(
            child: ListTile(
              isThreeLine: true,
              leading: _buildAvatar(u),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      u.isOwner ? 'Owner' : u.username,
                    ),
                  ),
                  Text(
                    'Level ${u.level}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                '${u.email}\nXP: ${u.xp}',
              ),
              trailing: canModify
                  ? PopupMenuButton<int>(
                      tooltip: 'Set level',
                      onSelected: (lvl) {
                        setState(() {
                          UserStore.instance
                              .setUserLevel(u, lvl);
                        });
                      },
                      itemBuilder: (context) {
                        return List.generate(
                          6,
                          (lvl) => PopupMenuItem(
                            value: lvl,
                            child: Text('Set Level $lvl'),
                          ),
                        );
                      },
                    )
                  : (u.id == me.id
                      ? const Text(
                          'You',
                          style: TextStyle(color: Colors.grey),
                        )
                      : null),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(NexusUser u) {
    if (u.avatarUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(u.avatarUrl),
      );
    }
    return CircleAvatar(
      child: Text(
        (u.username.isNotEmpty
                ? u.username[0]
                : u.email[0])
            .toUpperCase(),
      ),
    );
  }
}

/// PROFILE

class ProfileScreen extends StatefulWidget {
  final NexusUser user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _avatarController;
  late TextEditingController _passwordController;
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.user.username);
    _avatarController =
        TextEditingController(text: widget.user.avatarUrl);
    _passwordController =
        TextEditingController(text: widget.user.password);
    _dob = widget.user.dob;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _avatarController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 80);
    final last = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: first,
      lastDate: last,
    );

    if (picked != null) {
      setState(() {
        _dob = picked;
      });
    }
  }

  void _save() {
    final user = widget.user;
    user.username = _usernameController.text.trim().isEmpty
        ? user.username
        : _usernameController.text.trim();
    user.avatarUrl = _avatarController.text.trim();
    user.password = _passwordController.text.trim();
    user.dob = _dob;

    UserStore.instance.updateUser(user);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    final thresholds = UserStore.levelThresholds.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    int currentLevel = user.level;
    int previousThreshold = 0;
    int? nextThreshold;
    int? nextLevel;

    for (final e in thresholds) {
      if (e.key <= currentLevel) {
        previousThreshold = e.value;
      } else {
        nextLevel = e.key;
        nextThreshold = e.value;
        break;
      }
    }

    double progress = 1.0;
    String progressLabel = 'Max level reached for XP';
    if (currentLevel < 4 && nextThreshold != null) {
      final span = nextThreshold - previousThreshold;
      final currentAbove = (user.xp - previousThreshold)
          .clamp(0, span);
      progress = span == 0 ? 0 : currentAbove / span;
      progressLabel =
          'XP ${user.xp} / $nextThreshold (to Level $nextLevel)';
    } else if (currentLevel == 4) {
      progressLabel =
          'Level 4 – further promotion is manual (Level 5+)';
      progress = 1.0;
    } else if (currentLevel >= 5) {
      progressLabel = 'Level ${user.level} (manual rank)';
      progress = 1.0;
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                _buildAvatar(user),
                const SizedBox(height: 8),
                Text(
                  user.username,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.email} • Level ${user.level}${user.isOwner ? ' (Owner)' : ''}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'XP: ${user.xp}',
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress
                        .clamp(0.0, 1.0)
                        .toDouble(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    progressLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _avatarController,
            decoration: const InputDecoration(
              labelText: 'Avatar URL (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of birth'),
            subtitle: Text(
              _dob == null
                  ? 'Not set'
                  : _dob.toString().split(' ').first,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _pickDob,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(NexusUser u) {
    if (u.avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 32,
        backgroundImage: NetworkImage(u.avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 32,
      child: Text(
        (u.username.isNotEmpty
                ? u.username[0]
                : u.email[0])
            .toUpperCase(),
      ),
    );
  }
}

/// CHAT SCREEN: hub for channels + DMs

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = UserStore.instance.currentUser!;
    final chat = ChatStore.instance;

    final channels = chat.channelsForUser(user);
    final otherUsers = UserStore.instance.users
        .where((u) => u.email.toLowerCase() != user.email.toLowerCase())
        .toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.chat_bubble_outline),
            title: Text('Channels & Direct Messages'),
            subtitle: Text(
              'Pick a channel or open a direct thread. Levels control who can see what.',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Channels',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (channels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No channels available for your level.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...channels.map((c) {
              final unread = chat.unreadForChannel(user, c);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(c.name),
                  subtitle: Text(
                    '${c.description}\nLevel ${c.minLevel}+',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing:
                      unread > 0 ? _UnreadBadge(count: unread) : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChannelChatScreen(channel: c),
                      ),
                    );
                  },
                ),
              );
            }),
          const SizedBox(height: 16),
          const Text(
            'Direct messages',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (otherUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'You are the only user right now.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...otherUsers.map((u) {
              final unread = chat.unreadForDm(user, u);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (u.username.isNotEmpty
                              ? u.username[0]
                              : u.email[0])
                          .toUpperCase(),
                    ),
                  ),
                  title: Text(u.username),
                  subtitle: Text(u.email),
                  trailing:
                      unread > 0 ? _UnreadBadge(count: unread) : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DirectChatScreen(otherUser: u),
                      ),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        display,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// CHANNEL CHAT

class ChannelChatScreen extends StatefulWidget {
  final ChatChannel channel;

  const ChannelChatScreen({super.key, required this.channel});

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  void _markRead() {
    final user = UserStore.instance.currentUser;
    if (user == null) return;
    user.lastReadChannels[widget.channel.id] = DateTime.now();
    UserStore.instance.updateUser(user);
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final user = UserStore.instance.currentUser;
    if (user == null) return;

    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    ChatStore.instance.addChannelMessage(
      channelId: widget.channel.id,
      authorEmail: user.email,
      text: text,
    );
    _msgController.clear();
    _markRead();

    setState(() {});
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = UserStore.instance.currentUser!;
    final messages =
        ChatStore.instance.messagesForChannel(widget.channel.id);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.channel.name),
            Text(
              widget.channel.description,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final u =
                    UserStore.instance.getUser(m.authorEmail);
                final name = u?.username ?? m.authorEmail;
                final isMe =
                    m.authorEmail.toLowerCase() ==
                        user.email.toLowerCase();

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 320),
                    child: Card(
                      color:
                          isMe ? Colors.teal.withOpacity(0.4) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? 'You' : name,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(m.text),
                            const SizedBox(height: 2),
                            Text(
                              m.createdAt
                                  .toLocal()
                                  .toString()
                                  .split('.')
                                  .first,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          if (!widget.channel.readOnly)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.channel.name}',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Read-only channel.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

/// DIRECT MESSAGES

class DirectChatScreen extends StatefulWidget {
  final NexusUser otherUser;

  const DirectChatScreen({super.key, required this.otherUser});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  void _markRead() {
    final me = UserStore.instance.currentUser;
    if (me == null) return;
    me.lastReadDms[widget.otherUser.email.toLowerCase()] =
        DateTime.now();
    UserStore.instance.updateUser(me);
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final me = UserStore.instance.currentUser;
    if (me == null) return;

    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    ChatStore.instance.addDirectMessage(
      fromEmail: me.email,
      toEmail: widget.otherUser.email,
      text: text,
    );
    _msgController.clear();
    _markRead();

    setState(() {});
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = UserStore.instance.currentUser!;
    final messages = ChatStore.instance
        .messagesForDirect(me.email, widget.otherUser.email);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUser.username),
            Text(
              widget.otherUser.email,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[index];
                final isMe =
                    m.authorEmail.toLowerCase() ==
                        me.email.toLowerCase();

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 320),
                    child: Card(
                      color:
                          isMe ? Colors.teal.withOpacity(0.4) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? 'You' : widget.otherUser.username,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(m.text),
                            const SizedBox(height: 2),
                            Text(
                              m.createdAt
                                  .toLocal()
                                  .toString()
                                  .split('.')
                                  .first,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ADMIN CONTROL PANEL (for level 5+)

class AdminControlScreen extends StatefulWidget {
  const AdminControlScreen({super.key});

  @override
  State<AdminControlScreen> createState() =>
      _AdminControlScreenState();
}

class _AdminControlScreenState extends State<AdminControlScreen> {
  @override
  Widget build(BuildContext context) {
    final system = SystemStateStore.instance;
    final user = UserStore.instance.currentUser!;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.security),
            title: Text('Control Panel'),
            subtitle: Text(
              'High-level controls for the Archive state. '
              'These are local-only toggles right now (no real destructive power).',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Lockdown mode'),
            subtitle: const Text(
              'When enabled, a red banner appears across the app to signal restricted operations.',
            ),
            value: system.lockdown,
            onChanged: (v) {
              setState(() {
                system.lockdown = v;
              });
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Arm self-destruct system'),
            subtitle: const Text(
              'Visual-only. This will show an orange warning banner on Archive screens.',
            ),
            value: system.selfDestructArmed,
            onChanged: (v) {
              setState(() {
                system.selfDestructArmed = v;
              });
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Lockdown: '
                      '${system.lockdown ? "ACTIVE" : "Normal"}'),
                  Text('Self-destruct: '
                      '${system.selfDestructArmed ? "ARMED" : "Safe"}'),
                  const SizedBox(height: 12),
                  Text(
                    'Controller: ${user.username} (${user.email})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// NEXUS SCREEN (Level 6 only – backup vault)

class NexusScreen extends StatefulWidget {
  const NexusScreen({super.key});

  @override
  State<NexusScreen> createState() => _NexusScreenState();
}

class _NexusScreenState extends State<NexusScreen> {
  String _snapshot = '';

  @override
  void initState() {
    super.initState();
    _generateSnapshot();
  }

  void _generateSnapshot() {
    setState(() {
      _snapshot = BackupHelper.buildDataSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = UserStore.instance.currentUser!;
    if (user.level < 6) {
      // hard guard, just in case
      return const Center(
        child: Text('Access denied.'),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.memory),
            title: Text('Nexus Core'),
            subtitle: Text(
              'This is the hidden core of the Archive. In-universe, this would be the one place that must never be lost.',
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Code Backup (Conceptual)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'In a real deployment, this section would hold an encrypted snapshot of the Archive\'s source code '
                    '(e.g., the Git repository or main app bundle). '
                    'Because this is a self-contained demo running from compiled code, the actual source cannot be auto-exported here.\n\n'
                    'Treat this panel as the "slot" where you would plug that backup in – on your machine, the source of the Archive '
                    'is the main.dart file and its project directory.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data Snapshot',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This is a JSON-style backup of all users, entries, comments, community items, channels, and chat messages '
                    'currently loaded in memory. In a future version, this could be written to disk as a secure export.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _generateSnapshot,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 300,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111317),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade800,
                        ),
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8.0),
                          child: SelectableText(
                            _snapshot,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to build backup snapshot

class BackupHelper {
  static String buildDataSnapshot() {
    final userStore = UserStore.instance;
    final entryStore = EntryStore.instance;
    final communityStore = CommunityStore.instance;
    final chatStore = ChatStore.instance;

    final data = {
      'generatedAt': DateTime.now().toIso8601String(),
      'users': userStore.users.map((u) {
        return {
          'id': u.id,
          'email': u.email,
          'username': u.username,
          'level': u.level,
          'isOwner': u.isOwner,
          'avatarUrl': u.avatarUrl,
          'dob': u.dob?.toIso8601String(),
          'createdAt': u.createdAt.toIso8601String(),
          'xp': u.xp,
          'lastReadChannels': u.lastReadChannels.map(
            (key, value) => MapEntry(key, value.toIso8601String()),
          ),
          'lastReadDms': u.lastReadDms.map(
            (key, value) => MapEntry(key, value.toIso8601String()),
          ),
        };
      }).toList(),
      'entries': entryStore.entries.map((e) {
        return {
          'id': e.id,
          'title': e.title,
          'content': e.content,
          'category': e.category,
          'createdByEmail': e.createdByEmail,
          'createdAt': e.createdAt.toIso8601String(),
          'minLevel': e.minLevel,
          'pinned': e.pinned,
          'system': e.system,
          'isCommunity': e.isCommunity,
          'attachmentUrls': e.attachmentUrls,
          'spreadsheetName': e.spreadsheetName,
          'spreadsheetCsv': e.spreadsheetCsv,
        };
      }).toList(),
      'comments': entryStore.allComments.map((c) {
        return {
          'id': c.id,
          'entryId': c.entryId,
          'authorEmail': c.authorEmail,
          'text': c.text,
          'createdAt': c.createdAt.toIso8601String(),
        };
      }).toList(),
      'communityItems': communityStore.allItems.map((i) {
        return {
          'id': i.id,
          'entryId': i.entryId,
          'addedByEmail': i.addedByEmail,
          'label': i.label,
          'url': i.url,
          'createdAt': i.createdAt.toIso8601String(),
        };
      }).toList(),
      'channels': chatStore.channels.map((c) {
        return {
          'id': c.id,
          'name': c.name,
          'description': c.description,
          'minLevel': c.minLevel,
          'readOnly': c.readOnly,
        };
      }).toList(),
      'chatMessages': chatStore.messages.map((m) {
        return {
          'id': m.id,
          'type': m.type.name,
          'authorEmail': m.authorEmail,
          'text': m.text,
          'createdAt': m.createdAt.toIso8601String(),
          'channelId': m.channelId,
          'recipientEmail': m.recipientEmail,
        };
      }).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }
}
