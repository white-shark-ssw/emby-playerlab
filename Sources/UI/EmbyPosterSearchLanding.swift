import SwiftUI
import UIKit

// Metadata and actions remain in Search. The reusable header only presents them inside the wall.
struct EmbyPosterLandingHeaderInput {
    let history: [String]
    let showsRecommendations: Bool
    let onHistory: (String) -> Void
    let onClearHistory: () -> Void
    var height: CGFloat { (history.isEmpty ? 0 : 64) + (showsRecommendations ? (history.isEmpty ? 34 : 58) : 0) }
}

private final class EmbyPosterHistoryCell: UICollectionViewCell {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 13); label.textColor = .label; label.lineBreakMode = .byTruncatingTail
        contentView.backgroundColor = .secondarySystemBackground; contentView.layer.cornerRadius = 13
        contentView.addSubview(label); isAccessibilityElement = true; accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); label.frame = contentView.bounds.insetBy(dx: 12, dy: 0) }
}

final class EmbyPosterLandingHeader: UICollectionReusableView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let historyTitle = UILabel()
    private let recommendationTitle = UILabel()
    private let clear = UIButton(type: .system)
    private let historyFlow = UICollectionViewFlowLayout()
    private lazy var historyList = UICollectionView(frame: .zero, collectionViewLayout: historyFlow)
    private var input: EmbyPosterLandingHeaderInput?

    override init(frame: CGRect) {
        super.init(frame: frame)
        historyTitle.text = "搜索历史"; recommendationTitle.text = "推荐观看"
        for label in [historyTitle, recommendationTitle] { label.font = .systemFont(ofSize: 20, weight: .bold); label.textColor = .label; addSubview(label) }
        clear.setImage(UIImage(systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19)), for: .normal)
        clear.accessibilityLabel = "清除搜索历史"; clear.addTarget(self, action: #selector(clearHistory), for: .touchUpInside); addSubview(clear)
        historyFlow.scrollDirection = .horizontal; historyFlow.minimumLineSpacing = 8
        historyFlow.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        historyList.backgroundColor = .clear; historyList.showsHorizontalScrollIndicator = false; historyList.scrollsToTop = false
        historyList.accessibilityIdentifier = "poster-history"
        historyList.dataSource = self; historyList.delegate = self
        historyList.register(EmbyPosterHistoryCell.self, forCellWithReuseIdentifier: "history")
        addSubview(historyList)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ value: EmbyPosterLandingHeaderInput?) {
        let historyChanged = input?.history != value?.history
        input = value
        let hidden = value?.history.isEmpty ?? true
        historyTitle.isHidden = hidden; historyList.isHidden = hidden; clear.isHidden = hidden
        recommendationTitle.isHidden = !(value?.showsRecommendations ?? false)
        if historyChanged { historyList.reloadData() }
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        historyTitle.frame = CGRect(x: 16, y: 0, width: max(0, bounds.width - 78), height: 30)
        clear.frame = CGRect(x: bounds.width - 46, y: 0, width: 30, height: 30)
        historyList.frame = CGRect(x: 0, y: 38, width: bounds.width, height: 26)
        recommendationTitle.frame = CGRect(x: 16, y: input?.history.isEmpty == false ? 88 : 0, width: max(0, bounds.width - 32), height: 24)
    }
    @objc private func clearHistory() { input?.onClearHistory() }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { input?.history.count ?? 0 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "history", for: indexPath) as! EmbyPosterHistoryCell
        let term = input?.history[indexPath.item] ?? ""
        cell.label.text = term; cell.accessibilityLabel = term; return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let term = input?.history[indexPath.item] ?? ""
        let measured = (term as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 13)]).width
        return CGSize(width: min(max(48, ceil(measured) + 24), max(48, bounds.width - 32)), height: 26)
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard let input, indexPath.item < input.history.count else { return }
        input.onHistory(input.history[indexPath.item])
    }
}

struct EmbyPosterSearchLanding: View {
    let items: [LibraryItem]
    let revision: Int
    let history: [String]
    let recommendationsEnabled: Bool
    let isLoading: Bool
    let client: EmbyAPIClient
    let bottomPadding: CGFloat
    let isActive: Bool
    let onHistory: (String) -> Void
    let onClearHistory: () -> Void
    let onApproachingEnd: () -> Void

    var body: some View {
        EmbyPosterResultsPage(items: recommendationsEnabled ? items : [], revision: revision, replacement: 0, client: client, queryIdentity: "search-landing|\(recommendationsEnabled)", isLoading: recommendationsEnabled && isLoading, hasLoaded: !isLoading, error: nil, emptyText: "", bottomPadding: bottomPadding, onApproachingEnd: onApproachingEnd, horizontalPadding: 6, topPadding: 0, imagePixelWidth: V3SearchRecommendationPolicy.posterImageMaxWidth, loadAheadItemCount: 1, landingHeader: EmbyPosterLandingHeaderInput(history: history, showsRecommendations: recommendationsEnabled && (isLoading || !items.isEmpty), onHistory: onHistory, onClearHistory: onClearHistory), emptyFooterHeight: 52, isActive: isActive)
    }
}
