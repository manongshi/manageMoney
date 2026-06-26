import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme.dart';
import '../widgets/common_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    return PageScaffold(
      title: '我的',
      subtitle: '账户和运行信息',
      action: IconButton.filledTonal(
        tooltip: '刷新用户信息',
        onPressed: controller.loadProfile,
        icon: const Icon(Icons.refresh),
      ),
      children: [
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.nickname ?? '未命名用户',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.username ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionGap(),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '后端地址',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              SelectableText(
                controller.api.baseUrl,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SectionGap(),
        FilledButton.icon(
          onPressed: () async {
            try {
              await controller.logout();
            } catch (error) {
              if (!context.mounted) return;
              showAppMessage(context, error.toString());
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('退出登录'),
        ),
      ],
    );
  }
}
