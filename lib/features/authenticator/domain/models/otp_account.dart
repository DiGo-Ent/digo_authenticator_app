import 'dart:math';

class OtpAccount {
  final String id;
  final String issuer;
  final String accountName;
  final String secret; // Decrypted base32 secret at runtime
  final String algorithm; // 'SHA1', 'SHA256', 'SHA512'
  final int digits; // 6 or 8
  final int period; // 15, 30, 60
  final String type; // 'totp' or 'hotp'
  final int counter; // HOTP counter
  final String notes; // Decrypted notes
  final bool isFavorite;
  final String groupName;
  final int sortOrder;

  OtpAccount({
    required this.id,
    required this.issuer,
    required this.accountName,
    required this.secret,
    required this.algorithm,
    required this.digits,
    required this.period,
    required this.type,
    required this.counter,
    required this.notes,
    required this.isFavorite,
    required this.groupName,
    required this.sortOrder,
  });

  OtpAccount copyWith({
    String? id,
    String? issuer,
    String? accountName,
    String? secret,
    String? algorithm,
    int? digits,
    int? period,
    String? type,
    int? counter,
    String? notes,
    bool? isFavorite,
    String? groupName,
    int? sortOrder,
  }) {
    return OtpAccount(
      id: id ?? this.id,
      issuer: issuer ?? this.issuer,
      accountName: accountName ?? this.accountName,
      secret: secret ?? this.secret,
      algorithm: algorithm ?? this.algorithm,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      type: type ?? this.type,
      counter: counter ?? this.counter,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      groupName: groupName ?? this.groupName,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  // Parse from URI
  static OtpAccount fromUri(String uriString) {
    final uri = Uri.parse(uriString.trim());
    if (uri.scheme != 'otpauth') {
      throw const FormatException('Invalid URI scheme: must be otpauth://');
    }

    final type = uri.host.toLowerCase();
    if (type != 'totp' && type != 'hotp') {
      throw FormatException('Invalid OTP type: $type');
    }

    // Path represents the label. Label format: [issuer:]accountName
    var label = Uri.decodeComponent(uri.path.replaceFirst('/', ''));
    String issuer = '';
    String accountName = label;

    if (label.contains(':')) {
      final parts = label.split(':');
      issuer = parts[0].trim();
      accountName = parts.sublist(1).join(':').trim();
    }

    final params = uri.queryParameters;
    final secret = params['secret'];
    if (secret == null || secret.isEmpty) {
      throw const FormatException('Missing secret parameter');
    }

    final issuerParam = params['issuer'];
    if (issuerParam != null && issuerParam.isNotEmpty) {
      issuer = issuerParam;
    }

    final algorithm = params['algorithm']?.toUpperCase() ?? 'SHA1';
    final digits = int.tryParse(params['digits'] ?? '6') ?? 6;
    final period = int.tryParse(params['period'] ?? '30') ?? 30;
    final counter = int.tryParse(params['counter'] ?? '0') ?? 0;

    return OtpAccount(
      id: '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1000)}',
      issuer: issuer.isEmpty ? 'Unknown' : issuer,
      accountName: accountName.isEmpty ? 'Account' : accountName,
      secret: secret,
      algorithm: algorithm,
      digits: digits,
      period: period,
      type: type,
      counter: counter,
      notes: '',
      isFavorite: false,
      groupName: '',
      sortOrder: 0,
    );
  }

  // Convert to URI
  String toUri() {
    final encodedLabel = Uri.encodeComponent('$issuer:$accountName');
    final queryParams = {
      'secret': secret,
      'issuer': issuer,
      'algorithm': algorithm,
      'digits': digits.toString(),
      if (type == 'totp') 'period': period.toString(),
      if (type == 'hotp') 'counter': counter.toString(),
    };
    final queryString = queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return 'otpauth://$type/$encodedLabel?$queryString';
  }

  // To SQL Map (inserts encrypted secrets into DB)
  Map<String, dynamic> toSqlMap(String encryptedSecret, String encryptedNotes) {
    return {
      'id': id,
      'issuer': issuer,
      'account_name': accountName,
      'encrypted_secret': encryptedSecret,
      'algorithm': algorithm,
      'digits': digits,
      'period': period,
      'type': type,
      'counter': counter,
      'encrypted_notes': encryptedNotes,
      'is_favorite': isFavorite ? 1 : 0,
      'group_name': groupName,
      'sort_order': sortOrder,
    };
  }

  // From SQL Map
  static OtpAccount fromSqlMap(Map<String, dynamic> map, String decryptedSecret, String decryptedNotes) {
    return OtpAccount(
      id: map['id'] as String,
      issuer: map['issuer'] as String? ?? 'Unknown',
      accountName: map['account_name'] as String? ?? 'Account',
      secret: decryptedSecret,
      algorithm: map['algorithm'] as String? ?? 'SHA1',
      digits: map['digits'] as int? ?? 6,
      period: map['period'] as int? ?? 30,
      type: map['type'] as String? ?? 'totp',
      counter: map['counter'] as int? ?? 0,
      notes: decryptedNotes,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      groupName: map['group_name'] as String? ?? '',
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}
