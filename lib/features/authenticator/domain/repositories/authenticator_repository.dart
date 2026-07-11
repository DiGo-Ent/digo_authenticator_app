import '../models/otp_account.dart';

abstract class AuthenticatorRepository {
  Future<List<OtpAccount>> getAccounts();
  Future<void> saveAccount(OtpAccount account);
  Future<void> updateAccount(OtpAccount account);
  Future<void> deleteAccount(String id);
  Future<void> updateSortOrders(List<OtpAccount> accounts);
}
