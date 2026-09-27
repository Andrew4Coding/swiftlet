//
//  HomeView.swift
//  Swiftlet
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: [SortDescriptor(\Wallet.sortIndex), SortDescriptor(\Wallet.createdAt)]) private var allWallets: [Wallet]
    @Query(sort: \TransactionCategory.sortIndex) private var categories: [TransactionCategory]
    @Environment(AuthenticationService.self) private var authService

    @State private var viewModel = HomeViewModel()
    @State private var isPresentingAdd = false
    @State private var isPresentingWalletEditor = false
    @State private var dismissedInsightIDs: Set<String> = []

    private var wallets: [Wallet] {
        allWallets.filter { !$0.isArchived }
    }

    private var visibleInsights: [SpendingInsight] {
        SpendingInsightEngine.insights(categories: categories, transactions: allTransactions)
            .filter { !dismissedInsightIDs.contains($0.id) && !InsightDismissals.isDismissed($0) }
    }

    private var displayName: String? {
        if case let .signedIn(_, name) = authService.state { name } else { nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HomeHeader(displayName: displayName)

                    BalanceCard(
                        totalBalance: wallets.reduce(Decimal(0)) { $0 + $1.balance },
                        income: viewModel.totalIncome(from: allTransactions),
                        expense: viewModel.totalExpense(from: allTransactions),
                        incomeChange: viewModel.change(of: .income, from: allTransactions),
                        expenseChange: viewModel.change(of: .expense, from: allTransactions),
                        period: $viewModel.selectedPeriod
                    )

                    ForEach(visibleInsights.prefix(2)) { insight in
                        InsightBanner(insight: insight) {
                            InsightDismissals.dismiss(insight)
                            _ = withAnimation(.snappy) { dismissedInsightIDs.insert(insight.id) }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    WalletCarousel(wallets: wallets) { isPresentingWalletEditor = true }

                    BudgetsCard(progress: BudgetCalculator.progress(for: categories, transactions: allTransactions))

                    let purposeSlices = viewModel.purposeBreakdown(from: allTransactions)
                    if !purposeSlices.isEmpty {
                        PurposeBreakdownCard(slices: purposeSlices)
                    }

                    CategoryBreakdownChart(slices: viewModel.categoryBreakdown(from: allTransactions))

                    StatsSectionView(transactions: allTransactions, selectedPeriod: $viewModel.selectedPeriod)

                    RecentTransactionsSection(transactions: viewModel.recentTransactions(from: allTransactions))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(SkyBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Transaction", systemImage: "plus") { isPresentingAdd = true }
                        .buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $isPresentingAdd) {
                AddTransactionView()
            }
            .sheet(isPresented: $isPresentingWalletEditor) {
                WalletEditorView()
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(AuthenticationService())
        .modelContainer(for: [Transaction.self, TransactionCategory.self, Wallet.self], inMemory: true)
}
