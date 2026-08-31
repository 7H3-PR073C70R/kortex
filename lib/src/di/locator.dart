import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/interceptors/dio_interceptors.dart';
import 'package:kortex/src/core/themes/theme_cubit.dart';
import 'package:kortex/src/features/auth/data/client/auth_api_client.dart';
import 'package:kortex/src/features/auth/data/data_sources/auth_remote_data_source.dart';
import 'package:kortex/src/features/auth/data/data_sources/auth_remote_data_source_impl.dart';
import 'package:kortex/src/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/onboarding/data/datasources/onboarding_local_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/calibration_local_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/repositories/calibration_repository_impl.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/get_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/save_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_content/data/data_sources/content_recommendation_data_source.dart';
import 'package:kortex/src/features/onboarding_content/data/repositories/content_recommendation_repository_impl.dart';
import 'package:kortex/src/features/onboarding_content/domain/repositories/content_recommendation_repository.dart';
import 'package:kortex/src/features/onboarding_content/domain/use_cases/get_recommended_content_use_case.dart';
import 'package:kortex/src/features/onboarding_content/presentation/bloc/content_recommendation_cubit.dart';
import 'package:kortex/src/features/onboarding_utility/data/repositories/otp_repository_impl.dart';
import 'package:kortex/src/features/onboarding_utility/domain/repositories/otp_repository.dart';
import 'package:kortex/src/features/onboarding_utility/domain/use_cases/resend_otp_use_case.dart';
import 'package:kortex/src/features/onboarding_utility/domain/use_cases/verify_otp_use_case.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/bloc/otp_cubit.dart';
import 'package:kortex/src/services/local_storage_service.dart';
import 'package:kortex/src/services/user_storage_service.dart';
import 'package:logger/logger.dart';

part 'client_locator.dart';
part 'data_source_locator.dart';
part 'external_locator.dart';
part 'repository_locator.dart';
part 'service_locator.dart';
part 'use_case_locator.dart';

final GetIt locator = GetIt.instance;

void initLocator() {
  _initExternal();
  _initClients();
  _initDataSource();
  _initRepositoryLocator();
  _initUseCaseLocator();
  _initServices();
}
