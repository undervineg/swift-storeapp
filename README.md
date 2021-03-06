# 쇼핑 앱

## 테이블 커스텀 셀 구현
- 썸네일은 아직 표시 안 함.

![](img/step1.png)

### 프로토타입 셀 구성
- IB > Style : Custom
- IB > Identifier : ListCell

![](img/step1-1.png)

### 커스텀 뷰 클래스
- IB와 연결
	- IB > Custom Class > Class : ItemCell

```swift
class ItemCell: UITableViewCell {
    @IBOutlet weak var thumbnail: UIImageView!              // 썸네일
    @IBOutlet weak var title: UILabel!                      // 제목
    @IBOutlet weak var titleDescription: UILabel!           // 설명
    @IBOutlet weak var pricesContainer: PricesContainer!    // 정가, 할인가
    @IBOutlet weak var badges: BadgesContainer?             // 뱃지들
}
```

### 모델 클래스
#### 구조

```swift
struct StoreItem {
    let detailHash: String
    let image: String
    let alt: String
    let deliveryTypes: [String]
    let title: String
    let description: String
    let salePrice: String
    let normalPrice: String?
    let badges: [String]?
}
```

#### JSON 파싱을 위해 Decodable 채택
- json 데이터를 모델 클래스로 파싱 가능.
- 이 때, json 데이터의 key와 coding key 이름이 다른 경우, rawData로 추가.

```swift
extension StoreItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case detailHash = "detail_hash"
        case image
        case alt
        case deliveryTypes = "delivery_type"
        case title
        case description
        case salePrice = "s_price"
        case normalPrice = "n_price"
        case badges = "badge"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.detailHash = try values.decode(String.self, forKey: .detailHash)
        self.image = try values.decode(String.self, forKey: .image)
        self.alt = try values.decode(String.self, forKey: .alt)
        self.deliveryTypes = try values.decode([String].self, forKey: .deliveryTypes)
        self.title = try values.decode(String.self, forKey: .title)
        self.description = try values.decode(String.self, forKey: .description)
        self.salePrice = try values.decode(String.self, forKey: .salePrice)
        self.normalPrice = try? values.decode(String.self, forKey: .normalPrice)
        self.badges = try? values.decode([String].self, forKey: .badges)
    }
}
```

#### JSON 파싱 위한 헬퍼 메소드
- getDataFromJSONFile: json 파일을 불러와 Data 타입으로 변환.
- decode: Data 를 특정 객체의 배열로 디코딩하여 반환.

```swift
static func decode<T: Decodable>(data: Data?, toType type: [T].Type) -> [T] {
    guard let data = data else { return [] }
    let decoder = JSONDecoder()
    var decodedData: [T] = [T]()
    do {
        decodedData = try decoder.decode(type, from: data)
    } catch {
        NSLog(error.localizedDescription)
    }
    return decodedData
}

static func getDataFromJSONFile(_ fileName: String) -> Data? {
    guard let path = Bundle.main.path(forResource: fileName, ofType: "json") else { return nil }
    let url = URL(fileURLWithPath: path)
    var data: Data?
    do {
        data = try Data(contentsOf: url)
    } catch {
        NSLog(error.localizedDescription)
    }
    return data
}
```

### 뷰컨트롤러
#### JSON 파싱 및 모델 객체 생성

```swift
class ViewController: UIViewController, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    private var items = [StoreItem]()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        let data = JSONParser.getDataFromJSONFile("main")
        self.items = JSONParser.decode(data: data, toType: [StoreItem].self)
    }
    ...
}
```

#### 뷰에 모델 삽입
- **[Required]** 시스템이 (특정 테이블의) 셀을 그릴 수 있도록 셀에 데이터를 삽입하여 전달.

```swift
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
	// 현재 셀의 데이터(모델)
    let currentRowData: StoreItem = self.items[indexPath.row]
    // 현재 셀(뷰)
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "ListCell") as? ItemCell else {
        return UITableViewCell()
    }
    // 각 셀에 데이터 삽입
    cell.title.text = currentRowData.title
    cell.titleDescription.text = currentRowData.description
    cell.pricesContainer.normalPrice?.attributedText = currentRowData.normalPrice?.strike
    cell.pricesContainer.salePrice.attributedText = currentRowData.salePrice.salesHighlight
    cell.badges?.appendItems(with: currentRowData.badges)
    return cell
}
```

#### 그 외 테이블 설정
- **[Required]** 테이블 섹션 하나 당 행 개수: 모델 개수와 동일하게 제공.

```swift
func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.items.count
}

```

- 데이터에 따라 자동으로 높이를 설정할 수 있도록 설정. 
- UITableViewAutomaticDimension은 오토레이아웃 제약을 줘야 작동함. 
- 그 전에 임시로 estimatedRowHeight를 준다.

```swift
override func viewWillAppear(_ animated: Bool) {
    self.tableView.estimatedRowHeight = 40
    self.tableView.rowHeight = UITableViewAutomaticDimension
}
```

### 뱃지 컨테이너를 위한 메소드
- 뱃지는 배열 데이터로, 몇 개가 들어올 지 모르며 가로로 차곡차곡 붙여야 함.
- 차곡차곡 붙이기 위해 Horizontal StackView를 사용.
- 하지만 오토레이아웃 적용을 위해 StackView의 너비가 이미 고정돼 있는 상황.
- 이를 해결하기 위해 추가되는 arrangedSubview들의 IntrinsicContentSize를 합하여 StackView의 너비를 동적으로 변경.

```swift
func resizeContainer() {
    var contentWidth: CGFloat = 0.0
    var contentHeight: CGFloat = 0.0
    self.arrangedSubviews.forEach {
    	 // 콘텐츠들의 IntrinsicContentSize를 사용.
        $0.invalidateIntrinsicContentSize()
        contentWidth += $0.intrinsicContentSize.width + self.spacing
        contentHeight = $0.intrinsicContentSize.height
    }
    // 기존에 적용한 오토레이아웃 제약사항을 무효화.
    self.translatesAutoresizingMaskIntoConstraints = false
    // 가로, 세로 제약사항 추가.
    self.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
    self.heightAnchor.constraint(equalToConstant: contentHeight).isActive = true
}
```

<br/>

## 오토레이아웃 적용
<img src="img/step2-1.png" width="30%"></img><img src="img/step2-2.png" width="30%"></img><img src="img/step2-3.png" width="30%"></img>
<img src="img/step2-4.png" width="30%"></img><img src="img/step2-5.png" width="30%"></img><img src="img/step2-6.png" width="30%"></img>
<img src="img/step2-7.png" width="30%"></img><img src="img/step2-8.png" width="30%"></img><img src="img/step2-9.png" width="30%"></img>
<img src="img/step2-10.png" width="30%"></img><img src="img/step2-11.png" width="30%"></img>

### 뱃지 추가 방법 수정
#### 뱃지 컨테이너 제약조건 변경
- 기존: 컨테이너에 뱃지를 하나씩 붙이면서 컨테이너 크기를 늘려나감.
- 제약조건을 수정하면서 기존 resizeContainer() 메소드 제거.
- **widthAnchor, heightAnchor priority: 1000(required) → 750**
	- 고정이 아닌 가변성을 띄게 됨.
- **trailing margin: <= 20** 
	- 아무리 너비가 늘어나더라도 가장 오른쪽에서 20만큼은 남겨둠.
- **Content Hugging Priority (Horizontal): 250 → 751**
	- 뱃지들의 콘텐츠 사이즈를 유지하고, 늘어나는 데 저항성 높임.
- **Content Compression Resistance Priority (Horizontal): 750 → 751**
	- 뱃지들의 콘텐츠 사이즈를 유지하고, 줄어드는 데 저항성 높임.

#### 뱃지가 중복되어 추가되는 문제 수정
- 문제점: 테이블뷰를 스크롤 시, 뱃지가 중복되어 추가됨.
- 원인: **커스텀 셀을 재사용하기 때문**.
- 해결방법: 커스텀 셀 클래스에서 **prepareForReuse()** 메소드를 오버라이드 하고, 뱃지 컨테이너의 서브뷰들을 초기화
	- 이 때, 단순히 서브뷰를 떼어내기만 하면 다른 곳에 뱃지가 추가되는 문제가 생김.
	- 반드시 **서브뷰의 설정돼 있던 데이터도 초기화**해줘야 한다.

```swift
override func prepareForReuse() {
    // 셀을 재사용하기 때문에 기존 셀에 뱃지가 남아있을 수 있음.
    badges.removeAllBadges()
}
```

```swift
func removeAllBadges() {
    self.arrangedSubviews.forEach {
        guard let label = $0 as? BadgeLabel else { return }
        // 단순히 서브뷰만 떼어내는 게 아니라, 기존 서브뷰들의 속성을 리셋해줘야 한다.
        label.reset()
        self.removeArrangedSubview(label)
    }
}
```

```swift
func reset() {
    self.text = nil
    self.font = nil
    self.textColor = nil
    self.backgroundColor = nil
    self.layer.cornerRadius = 0
    self.topInset = 0
    self.leftInset = 0
    self.bottomInset = 0
    self.rightInset = 0
}
```

<br/>

## Custom Section Header 적용

![](img/step3.png)

### 섹션 구조체
- 섹션별 제목, 부제목 및 StoreItem 모델 배열을 가짐

```swift
struct Section {
    let title: String
    let subtitle: String
    let cell: [StoreItem]
}
```

- 섹션 열거형 추가: 각 케이스별 제목, 부제목 데이터 반환 기능
	- 추후 섹션번호에 따라 TableSection 타입 생성 가능

```swift
enum TableSection: Int {
    case main = 0
    case soup
    case side

    var title: String {
        switch self {
        case .main: return "메인반찬"
        case .soup: return "국.찌게"
        case .side: return "밑반찬"
        }
    }

    var subtitle: String {
        switch self {
        case .main: return "한그릇 뚝딱 메인 요리"
        case .soup: return "김이 모락모락 국.찌게"
        case .side: return "언제 먹어도 든든한 밑반찬"
        }
    }
}
```

### 헤더를 위한 커스텀 셀 구성
- Nib 파일도 생성하여 대강의 레이아웃 구성
- 커스텀 클래스를 설계 - 제목, 부제목 뷰로 구성
- 재사용할 헤더셀은 Nib으로 만들었기 때문에 viewDidLoad에서 register해줘야 한다.

```swift
tableView.register(UINib(nibName: "HeaderCell", bundle: nil), forCellReuseIdentifier: "HeaderCell")
```

>- 주의할 점: 커스텀 클래스 추가하면서 nib 파일을 동시에 만든 경우, custom class 지정 하면 안된다. identifier만 지정한다.

### 뷰 컨트롤러에서 헤더 관련 메소드 오버라이드
- 섹션별 헤더 뷰에 데이터 삽입

```swift
func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let header = tableView.dequeueReusableCell(withIdentifier: "HeaderCell") as? HeaderCell else {
        return nil
    }
    header.title.text = items[section].title
    header.subtitle.text = items[section].subtitle
    return header
}
```

- 섹션 수

```swift
func numberOfSections(in tableView: UITableView) -> Int {
    return items.count
}
```

- 섹션 높이

```swift
func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    guard let header = tableView.dequeueReusableCell(withIdentifier: "HeaderCell") as? HeaderCell else {
        return 0.0
    }
    return header.frame.height
}
```

<br/>

## 패키지 관리, CocoaPod

![](img/step4.png)

### Toaster 설치
- vim Podfile → pod 'Toaster' → pod install
- import Toaster

### 테이블 셀 클릭 시, 제목 및 할인가격 토스트

```swift
func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let row = self.items[indexPath.section].cell[indexPath.row]
    ToastView.appearance().font = UIFont.boldSystemFont(ofSize: 15)
    let toaster = Toast(text: row.title+"\n"+row.salePrice)
    toaster.show()
}
```

### 학습 내용
>- **[프로젝트 설정 용어](https://stackoverflow.com/questions/20637435/xcode-what-is-a-target-and-scheme-in-plain-language/20637892#20637892)**

<br/>

## 서버 데이터 요청
### 네트워크 연결
- URL에서 데이터를 받아오기 위해 URLSession.shared의 dataTask 활용
- 요청한 데이터를 받으면 특정 타입 배열(여기서는 셀 데이터 타입)로 디코딩 후, 핸들러로 결과를 보냄.

```swift
static func download(urlString: String, toType type: [T].Type, completionHandler: @escaping DecodeResult) {
    guard let url = URL(string: urlString) else { return }
    URLSession.shared.dataTask(with: url) { (data, _, error) in
        guard let data = data else { return }
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(type, from: data)
            completionHandler(.success(result))
        } catch {
            completionHandler(.failure(error))
        }
    }.resume()
}
```

- 호출한 쪽: 셀 데이터 배열에 섹션 정보를 붙여 Section 데이터로 만든 후 섹션 배열에 붙임. 더해진 데이터만큼 메인 쓰레드에서 reloadData()를 통해 업데이트.

```swift
private func loadItemsFromAPI(from server: Server, forSection section: TableSection) {
    Downloader.download(urlString: section.api(from: server), toType: [StoreItem].self) { response -> Void in
        switch response {
        case .success(let items):
            let newSection = Section(type: section, cell: items)
            self.sections.append(newSection)
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        case .failure(let error): NSLog(error.localizedDescription)
        }
    }
}
```

### 로컬 서버 생성
- 시간 제한이 있는 api를 마음대로 사용하기 위해 로컬서버 만들어 사용.
- nodejs, express 사용

```swift
const express = require('express');
const app = express();
const hostname = '127.0.0.1';
const port = 3000;

app.use(express.static('resources'))

app.get('/main', (req, res) => {
	res.sendFile(__dirname + "/resources/main.json");
});

app.get('/soup', (req, res) => {
	res.sendFile(__dirname + "/resources/soup.json");
});

app.get('/side', (req, res) => {
	res.sendFile(__dirname + "/resources/side.json");
});

app.listen(port, () => {
	console.log('app listening on port \(port)');
});
```

### 학습 내용
>- **[Alamofire와 URLSession]()**
>- **[TableView insert/delete 과정]()**
>- **[Main Thread Checker](https://developer.apple.com/documentation/code_diagnostics/main_thread_checker)**

<br/>

## 썸네일 표시

![](img/step6.png)

### JSON 데이터 다운로드 중 썸네일 다운로드 쓰레드 생성
- JSON 데이터 다운로드 중, 썸네일 url을 통해 썸네일 다운로드 쓰레드 생성하여 저장
- 이를 위해 기존 StoreItem에 썸네일을 저장할 변수 추가
- Thumbnail 클래스 추가: 비동기 다운로드 메소드 추가

```swift
private func loadImage() {
    if let cachedData = CacheStorage.retrieve(url) {
        self.image = UIImage(data: cachedData)
    } else {
        Downloader.download(from: url, completionHandler: { response in
            switch response {
            case .success(let imageData):
                CacheStorage.save(self.url, imageData)
                self.image = UIImage(data: imageData)
            case .failure(let error): NSLog(error.localizedDescription)
            }
        })
    }
}
```

### 테이블 뷰 셀에 데이터 삽입 시, 이미지는 비동기로 삽입
- 썸네일 이미지가 있는 경우, 비동기로 표시

```swift
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
...
	DispatchQueue.main.async {
        cell.thumbnail.image = row.thumbnail?.image
    }
    
    return cell
}
```

### 섹션 데이터 로드 후, 섹션 insert 방식으로 변경
- 기존: 비동기로 tableView.reloadData()
- 변경: tableView.insertSection()

```swift
DispatchQueue.main.async(execute: {
    let newSection = Section(type: section, cell: items)
    self.sections.append(newSection)
    if let index = self.sections.index(of: newSection) {
        let indexSet = IndexSet(integer: index)
        self.tableView.insertSections(indexSet, with: .automatic)
    }
})
```

<br/>

## 상품 상세화면 구현

![](img/step7-1.png)

### 상세화면 화면구조
![](img/step7-2-1.png)
![](img/step7-2-2.png)

>- 주문하기 버튼은 전체 스크롤뷰에서 제외했으며, 항상 하단에 붙어있도록 함

### 상세화면 데이터 로드 및 화면 표시

- `http://crong.codesquad.kr:8080/woowa/detail/{detail_hash}` 형식으로 데이터를 받아 decode.
- json 데이터 형식은 다음과 같다.

```
{
	"hash": "H9881",
	"data": {
		"top_image": "https://cdn.bmf.kr/_data/product/H9881/910a01a81c49cb75414edb759237501f.jpg",
		"thumb_images": ["https://cdn.bmf.kr/_data/product/H9881/910a01a81c49cb75414edb759237501f.jpg", "https://cdn.bmf.kr/_data/product/H9881/fbf29077698ca16f8050e43476b47f38.jpg", "https://cdn.bmf.kr/_data/product/H9881/c96c6949efc3391148e9b280a2c5ed0b.jpg", "https://cdn.bmf.kr/_data/product/H9881/71411e15d2d961df496f87f08648b345.jpg", "https://cdn.bmf.kr/_data/product/H9881/437196dacf46b52b11d0bccbc4231558.jpg"],
		"product_description": "경상도 명물 요리 세 가지를 한 상에!",
		"point": "312원",
		"delivery_info": "서울 경기 새벽배송 / 전국택배 (제주 및 도서산간 불가) [화 · 수 · 목 · 금 · 토] 수령 가능한 상품입니다.",
		"delivery_fee": "2,500원 (40,000원 이상 구매 시 무료)",
		"prices": ["39,000원", "31,200원"],
		"detail_section": ["https://cdn.bmf.kr/_data/product/H9881/7fb1ddf1adeadc5410cecd79441f7b65.jpg", "https://cdn.bmf.kr/_data/product/H9881/b776c59544b516a184d1363c2c802789.jpg", "https://cdn.bmf.kr/_data/product/H9881/cc2b4a61db410096db0e3c497096d63f.jpg", "https://cdn.bmf.kr/_data/product/H9881/77970960c8efe0992f9746c37062e1e4.jpg", "https://cdn.bmf.kr/_data/product/H9881/aa56cec7d2fe4dde0b124c17a06ffda6.jpg", "https://cdn.bmf.kr/_data/product/H9881/c9fbe313767400ce21ea83bb2b9d8e96.jpg", "https://cdn.bmf.kr/_data/product/H9881/320939f0d0fbe8e4846e20111f1aa4ce.jpg", "https://cdn.bmf.kr/_data/product/H9881/5778ae933121c5d131889ecbf5e2874c.jpg", "https://cdn.bmf.kr/_data/product/H9881/785291ed7fe3f2a8c7e06f443dea7553.jpg", "https://cdn.bmf.kr/_data/product/H9881/92ef47f6efdd0286f6af7f712c3c838d.jpg", "https://cdn.bmf.kr/_data/product/H9881/c0319354245ee2963ccb97d60943e8ff.jpg", "https://cdn.bmf.kr/_data/product/H9881/07b1864a06f3b0b26af9a7148ac70cfb.jpg", "https://cdn.bmf.kr/_data/product/H9881/ba2aba220a55924a00c668dd13c4cee1.jpg"]
	}
}
```

- 중첩 구조로 되어있으므로, decodable 클래스도 2개로 나누어 구현

```swift
struct ItemDetail: Decodable {
    let hash: String
    let data: DetailData

    enum CodingKeys: String, CodingKey {
        case hash
        case data
    }
}
```

```swift
struct DetailData: Decodable {
    let topImage: String
    let thumbnailUrls: [String]
    let productDescription: String
    let point: String
    let deliveryInfo: String
    let deliveryFee: String
    let prices: [String]
    let detailSectionUrls: [String]
    var thumbnails: [Thumbnail]
    var detailSectionItems: [DetailImage]
 
    ...
}
```

#### 여러 이미지 로드 시, 한 장 불러올 때마다 뷰 업데이트
- 상단 가로 스크롤뷰에 들어갈 썸네일 및 하단 상세 이미지는 여러 장이기 때문에 한꺼번에 받아 처리하면 화면전환 시 느려질 수 있음
- 상단 가로 스크롤뷰의 썸네일은 Thumbnail 타입으로 생성
- 하단 상세 이미지는 DetailImage 타입으로 생성

```swift
struct DetailData: Decodable {
	...
	init(from decoder: Decoder) throws {
		...
		self.thumbnails = try thumbnailUrls.flatMap { urlString -> Thumbnail in
            try Thumbnail(urlString: urlString)
        }
        self.detailSectionItems = try detailSectionUrls.flatMap { urlString -> DetailImage in
            try DetailImage(urlString: urlString)
        }
        ...
    }
    ...
}    
```

- Thumbnail, DetailImage 타입은 생성 시 주입된 url로 비동기 이미지 로드를 시작한다. (내부 로직 동일)

```swift
class Thumbnail: AsyncPresentable {
    weak var delegate: PresentImageDelegate?
    var image: UIImage? {
        didSet {
            guard let image = image else { return }
            delegate?.present(self, image: image)
        }
    }

    init(urlString: String) throws {
        loadImage(from: urlString)
    }
}
```

- 이 때, 중복되는 코드를 줄이기 위해 AsyncPresentable 프로토콜을 선언한 후 이를 확장하여 이미지 로드 메소드를 구현했다.

```swift
protocol AsyncPresentable: class {
    func loadImage(from urlString: String)
    var image: UIImage? { get set }
}

extension AsyncPresentable {
    func loadImage(from urlString: String) {
        if let cachedData = CacheStorage.retrieve(urlString) {
            self.image = UIImage.init(data: cachedData)
        } else {
            Downloader.downloadToGlobalQueue(from: urlString, qos: .userInteractive, completionHandler: { response in
                switch response {
                case .success(let data):
                    try? CacheStorage.save(urlString, data)
                    self.image = UIImage(data: data)
                case .failure: self.presentGraySpace()
                }
            })
        }
    }
    ...
}
```

- 각 Thumbnail, DetailImage은 이미지가 세팅되면 뷰컨트롤러에게 알리며(델리게이트 활용), 뷰컨트롤러는 알림받은 콘텐츠의 타입에 따라 적합한 뷰에 표시한다.

```swift
extension DetailViewController: PresentImageDelegate {
    func present(_ contentType: AsyncPresentable, image: UIImage) {
        switch contentType {
        case is Thumbnail: self.detailView.configureThumbnailScrollView(image)
        case is DetailImage: self.detailView.configureDetailSection(image)
        default: break
        }
    }
}
```

### 주문버튼 클릭 시 슬랙으로 전송
#### 이전 화면으로 이동 및 주문정보 토스트
![](img/step7-3-1.png)
![](img/step7-3-2.png)

### 네트워크 에러 발생 시 상단에 에러 메시지 표시
- GSMessages 오픈api 사용

![](img/step7-4.png)