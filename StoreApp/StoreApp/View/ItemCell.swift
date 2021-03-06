//
//  ItemCell.swift
//  StoreApp
//
//  Created by 심 승민 on 2018. 2. 20..
//  Copyright © 2018년 심 승민. All rights reserved.
//

import UIKit

// 커스텀 셀 클래스 (뷰)
class ItemCell: UITableViewCell, StyleConfigurable, Reusable {
    @IBOutlet weak var thumbnail: UIImageView!              // 썸네일
    @IBOutlet weak var title: UILabel!                      // 제목
    @IBOutlet weak var titleDescription: UILabel!           // 설명
    @IBOutlet weak var pricesContainer: PricesContainer!    // 정가, 할인가
    @IBOutlet weak var badges: BadgesContainer!             // 뱃지들

    override func awakeFromNib() {
        super.awakeFromNib()
        configure()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // 셀을 재사용하기 때문에 기존 셀에 뱃지가 남아있을 수 있음.
        badges.removeAllBadges()
        thumbnail.image = nil
        titleDescription.text = nil
        pricesContainer.normalPrice.text = nil
        pricesContainer.salePrice.text = nil
    }

    func configure() {
        title.configure(style: Style.Title())
        titleDescription.configure(style: Style.Description())
    }

}
