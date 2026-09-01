import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/pages/user_profile_page.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';

@RoutePage()
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: locator<AuthBloc>()),
        BlocProvider<DashboardBloc>.value(value: locator<DashboardBloc>()),
      ],
      child: const UserProfilePage(),
    );
  }
}
