import 'package:flutter/widgets.dart';

final class StartupSplashPage extends StatelessWidget {
  const StartupSplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFFFFFFF),
      child: SizedBox.expand(
        child: Image(
          image: AssetImage('assets/images/bg_wel_new.png'),
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}
