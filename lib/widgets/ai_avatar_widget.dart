import 'package:flutter/material.dart';
import '../engine/cognitive/avatar_engine.dart';
import 'package:google_fonts/google_fonts.dart';

class AiAvatarWidget extends StatelessWidget {
  final AvatarEngine engine;

  const AiAvatarWidget({
    super.key, 
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset>(
      valueListenable: engine.position,
      builder: (context, position, child) {
        return Positioned(
          left: position.dx - 25, // Center horizontally (width 50)
          top: position.dy - 25,  // Center vertically (height 50)
          child: _AvatarBody(engine: engine),
        );
      },
    );
  }
}

class _AvatarBody extends StatelessWidget {
  final AvatarEngine engine;

  const _AvatarBody({required this.engine});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: engine.speechBubble,
          builder: (context, text, child) {
            if (text == null) return const SizedBox(height: 20);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
                ],
              ),
              child: Text(
                text,
                style: GoogleFonts.nanumPenScript(fontSize: 20),
              ),
            );
          },
        ),
        ValueListenableBuilder<AvatarState>(
          valueListenable: engine.state,
          builder: (context, state, child) {
            Color avatarColor = Colors.blueAccent;
            IconData icon = Icons.smart_toy;
            
            switch (state) {
              case AvatarState.idle:
                avatarColor = Colors.blueGrey;
                icon = Icons.face;
                break;
              case AvatarState.thinking:
                avatarColor = Colors.purpleAccent;
                icon = Icons.psychology;
                break;
              case AvatarState.observing:
                avatarColor = Colors.orangeAccent;
                icon = Icons.visibility;
                break;
              case AvatarState.generating:
                avatarColor = Colors.greenAccent;
                icon = Icons.auto_awesome;
                break;
              case AvatarState.helping:
                avatarColor = Colors.redAccent;
                icon = Icons.favorite;
                break;
              case AvatarState.following:
              case AvatarState.moving:
                avatarColor = Colors.blueAccent;
                icon = Icons.flight_takeoff;
                break;
            }

            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColor,
                boxShadow: [
                  BoxShadow(
                    color: avatarColor.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            );
          },
        ),
      ],
    );
  }
}
