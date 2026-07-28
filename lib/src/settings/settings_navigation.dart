import 'dart:async';

import 'package:flutter/material.dart';

import '../account_safety/account_safety_models.dart';
import '../startup/privacy_consent_dialog.dart';

typedef SettingsAgreementLauncher =
    FutureOr<void> Function(BuildContext context, AgreementDocument document);

typedef SettingsAccountSafetyLauncher =
    FutureOr<AccountSafetyResult?> Function(BuildContext context);
