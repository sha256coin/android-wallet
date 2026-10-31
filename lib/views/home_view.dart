import 'package:flutter/material.dart';
import 'package:s256_wallet/widgets/app_background.dart';
import 'package:s256_wallet/views/home/addressbook_view.dart';
import 'package:s256_wallet/views/home/exchange_view.dart';
import 'package:s256_wallet/views/home/wallet_view.dart';
import 'package:s256_wallet/views/home/settings_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          WalletView(),
          ExchangeView(),
          AddressbookView(),
          SettingsView(),
        ],
      ),
      // Labels and an amber line over the open tab, like the S256 web wallet.
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: S256Colors.darkBg,
          border: Border(top: BorderSide(color: S256Colors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (final (i, icon, label) in const [
                  (0, Icons.wallet, 'Wallet'),
                  (1, Icons.sync, 'Markets'),
                  (2, Icons.contact_page_rounded, 'Contacts'),
                  (3, Icons.settings, 'Settings'),
                ])
                  Expanded(child: _navItem(i, icon, label)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _selectedIndex == index;
    final color = selected ? S256Colors.primary : S256Colors.textLight;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Container(
          // No borderRadius: Flutter cannot round a border with one coloured side.
          decoration: BoxDecoration(
            color: selected ? S256Colors.glow : Colors.transparent,
            border: Border(
              top: BorderSide(color: selected ? S256Colors.primary : Colors.transparent, width: 2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'ChakraPetch',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
