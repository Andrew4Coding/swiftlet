import Foundation
import Testing

@testable import Swiftlet

struct BankEmailParserTests {
    private let bca = """
    Hello Andrew,
    You just made a transaction through myBCA.
    Here are the details of your transaction :

    Status\t:\tSuccessful
    Transaction Date\t:\t
    Transaction Type\t:\tQRIS Payment
    Payment to\t:\tWARUNG MAKAN
    Merchant Location\t:\tJAKARTA
    Acquirer\t:\tBCA
    Total Payment\t:\tIDR 56,661.00
    RRN\t:\t123456
    Reference No.\t:\tREF001
    If you do not recognize this transaction, immediately contact Halo BCA at 1500888.
    PT Bank Central Asia Tbk
    """

    private let bniQris = """
    Hai, Andrew

    Terima kasih udah bertransaksi dengan wondr by BNI! Kamu baru aja bayar pakai QRIS dengan detail sebagai berikut:
    Penerima
    SPBU 34.1234
    TANGSEL 1234
    Sumber dana
    Andrew
    TAPLUS MUDA • *******123
    Detail pembayaran
    Nominal\tRp282.150
    Total\tRp282.150
    Detail merchant
    Nama acquirer\tBCA
    Reference ID\tREFQRIS
    Kode RRN\t987654
    """

    private let bniTopUp = """
    Hai, Andrew

    Terima kasih udah memilih wondr by BNI untuk transaksi kamu! Kamu baru aja top-up e-Wallet dengan detail sebagai berikut:
    Penerima
    OVO-Andrew
    OVO • +62 812
    Sumber dana
    Andrew
    Detail top-up
    Nominal\tRp200.000
    Biaya transaksi\tRp0
    Total\tRp200.000
    Lainnya
    Ref ID\tTOPUP01
    """

    private let notice = """
    Payment Success
    No Referensi: NOTICE01

    Detail Merchant
    Nama Merchant\tKedai Andrew
    Nama Penerbit\tSeabank
    Nama Pengakuisisi\tBNI
    RRN\t555
    Detail Transaksi
    Nominal\tRp 30200.00
    Biaya MDR\tRp 0.00
    Total\tRp 30200.00
    """

    private let ovo = """
    Cotti Trade Indonesia
    Pembayaran Berhasil - Rp19.000

    24 Oct 2026, 10:00

    Nama Acquirer\tBank Neo Commerce
    Nama Toko\tCotti Trade Indonesia
    No. Referensi\tOVOREF1
    Nama Issuer\tOVO
    Metode Pembayaran\tOVO Cash

    Detail
    Pembayaran\tRp19.000
    Tip\tRp0

    Total\tRp19.000
    """

    private let grab = """
    Selamat menikmati makanan Anda!

    TOTAL
    Rp 43060\tTANGGAL   |  WAKTU
    14 Nov 26 12:00

    Detail Pesanan

    Jenis Kendaraan:
    GrabFood

    Pesanan ID
    A-123

    Pesanan Dari:
    Sushi Stop - Pagedangan
    Jl. Raya Pagedangan

    Detail Tagihan

    Detail Pembayaran:
    OVO Cash :   Rp 43060
    Detail Pembayaran:\t  Jumlah:
    1x   Sushi Tokyo Platter\t  Rp 54000

    Subtotal\t  Rp 54000
    Biaya Pengiriman\t  Rp 13000
    Rp10.000 off delivery\t- Rp 10000
    TOTAL (INCL. TAX)    \t  Rp 43060
    """

    private let pln = """
    Hai Andrew,
    Makasih udah bayar tagihanmu di GoTagihan!

    BERHASIL\t07 Nov 2026, 08:10
    ID Pembayaran - GT123
    \tPLN Token\tRp203.000
    Struk Pembayaran PLN Token

    DETAIL PEMBAYARAN
    Metode pembayaran\t
    No Meter\t
    No Ref\tXYZ
    Rp Bayar\tRp200.000
    PPJ\tRp5.826,00
    MeterAI\tRp0,00
    Admin Bank\tRp3.000
    Total Bayar\tRp200.000
    Total\tRp203.000
    """

    private let gojek = """
    Thanks for ordering GoRide
    Total paid\tRp17.500
    Payment details

    Trip fare\t\tRp14.500
    Total payment\t\tRp17.500
    Paid with GoPay\t\tRp17.500
    """

    @Test func parsesBCAQrisPayment() throws {
        let parsed = try #require(BankEmailParser.parse(bca))
        #expect(parsed.type == .expense)
        #expect(parsed.amount == 56661)
        #expect(parsed.title == "WARUNG MAKAN")
        #expect(parsed.walletHint == "BCA")
        #expect(parsed.reference == "REF001")
    }

    @Test func parsesBNIQris() throws {
        let parsed = try #require(BankEmailParser.parse(bniQris))
        #expect(parsed.type == .expense)
        #expect(parsed.amount == 282_150)
        #expect(parsed.title == "SPBU 34.1234")
        #expect(parsed.walletHint == "BNI")
        #expect(parsed.reference == "987654")
    }

    @Test func parsesBNITopUpAsTransfer() throws {
        let parsed = try #require(BankEmailParser.parse(bniTopUp))
        #expect(parsed.type == .transfer)
        #expect(parsed.amount == 200_000)
        #expect(parsed.walletHint == "BNI")
        #expect(parsed.destinationHint == "OVO")
        #expect(parsed.reference == "TOPUP01")
    }

    @Test func parsesMerchantNoticeAsIncome() throws {
        let parsed = try #require(BankEmailParser.parse(notice))
        #expect(parsed.type == .income)
        #expect(parsed.amount == 30200)
        #expect(parsed.title == "Kedai Andrew")
        #expect(parsed.walletHint == "BNI")
        #expect(parsed.reference == "NOTICE01")
    }

    @Test func parsesOVOMerchantReceipt() throws {
        let parsed = try #require(BankEmailParser.parse(ovo))
        #expect(parsed.type == .expense)
        #expect(parsed.amount == 19000)
        #expect(parsed.title == "Cotti Trade Indonesia")
        #expect(parsed.walletHint == "OVO")
        #expect(parsed.reference == "OVOREF1")
    }

    @Test func parsesGrabFinalTotalNotSubtotal() throws {
        let parsed = try #require(BankEmailParser.parse(grab))
        #expect(parsed.amount == 43060)
        #expect(parsed.title == "GrabFood · Sushi Stop")
        #expect(parsed.walletHint == "OVO")
        #expect(parsed.reference == "A-123")
    }

    @Test func parsesGoTagihanFinalTotalAndDefaultsToGoPay() throws {
        let parsed = try #require(BankEmailParser.parse(pln))
        #expect(parsed.amount == 203_000)
        #expect(parsed.title == "PLN Token")
        #expect(parsed.walletHint == "GoPay")
        #expect(parsed.reference == "GT123")
    }

    @Test func parsesGojekTripWithoutReference() throws {
        let parsed = try #require(BankEmailParser.parse(gojek))
        #expect(parsed.amount == 17500)
        #expect(parsed.title == "GoRide")
        #expect(parsed.walletHint == "GoPay")
        #expect(parsed.reference.isEmpty)
    }

    @Test func parsesBCAWhenEachTableCellIsItsOwnLine() throws {
        let cells = """
        You just made a transaction through myBCA.
        Status
        :
        Successful
        Payment to
        :
        WARUNG MAKAN
        Total Payment
        :
        IDR 56,661.00
        Reference No.
        :
        REF001
        """
        let parsed = try #require(BankEmailParser.parse(cells))
        #expect(parsed.amount == 56661)
        #expect(parsed.title == "WARUNG MAKAN")
        #expect(parsed.reference == "REF001")
    }

    @Test func parsesBCAFromHTMLTable() throws {
        let html = """
        <html><body><p>You just made a transaction through myBCA.</p>
        <table>
        <tr><td>Status</td><td>:</td><td>Successful</td></tr>
        <tr><td>Payment to</td><td>:</td><td>WARUNG&nbsp;MAKAN</td></tr>
        <tr><td>Total Payment</td><td>:</td><td>IDR 56,661.00</td></tr>
        <tr><td>Reference No.</td><td>:</td><td>REF001</td></tr>
        </table></body></html>
        """
        let parsed = try #require(BankEmailParser.parse(html))
        #expect(parsed.amount == 56661)
        #expect(parsed.title == "WARUNG MAKAN")
        #expect(parsed.reference == "REF001")
    }

    @Test func readsRupiahAmountsExactly() {
        #expect(BankEmailParser.rupiah("56,661.00") == 56661)
        #expect(BankEmailParser.rupiah("200.000") == 200_000)
        #expect(BankEmailParser.rupiah("30200.00") == 30200)
        #expect(BankEmailParser.rupiah("0,00") == 0)
        #expect(BankEmailParser.rupiah("5.826,00") == 5826)
        #expect(BankEmailParser.rupiah("43060") == 43060)
        #expect(BankEmailParser.amount(in: "Rp 43060") == 43060)
        #expect(BankEmailParser.amount(in: "IDR 56,661.00") == 56661)
    }

    @Test func rejectsUnknownAndFailedEmails() {
        #expect(BankEmailParser.parse("Hello, your newsletter is here") == nil)
        #expect(BankEmailParser.parse(bca.replacingOccurrences(of: "Successful", with: "Failed")) == nil)
    }
}
