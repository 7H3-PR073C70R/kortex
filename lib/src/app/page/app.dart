import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/app/router/app_router.dart';
import 'package:kortex/src/core/themes/theme_cubit.dart';
import 'package:kortex/src/core/themes/theme_state.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:kortex/src/shared/widgets/dismiss_keyboard.dart';

class App extends StatelessWidget {
  App({super.key});

  final appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(
          value: locator<ThemeCubit>(),
        ),
        BlocProvider<AuthBloc>.value(
          value: locator<AuthBloc>(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return DismissKeyboard(
            child: ScreenUtilInit(
              designSize: const Size(375, 812),
              builder: (context, _) => MaterialApp.router(
                theme: state.lightTheme,
                darkTheme: state.darkTheme,
                themeMode: state.themeMode,
                themeAnimationDuration: const Duration(milliseconds: 300),
                themeAnimationCurve: Curves.easeInOut,
                debugShowCheckedModeBanner: false,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: appRouter.config(),
              ),
            ),
          );
        },
      ),
    );
  }
}
