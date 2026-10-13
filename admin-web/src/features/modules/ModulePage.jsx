import React from "react";
import { PageHeading, Panel, TableTags } from "../../shared/ui.jsx";
import Icon from "../../shared/Icon.jsx";

// Màn cho các mục chưa dựng giao diện: hiển thị phạm vi dữ liệu và chức năng
// cần làm (lấy từ navigation.js) để làm đặc tả khi viết API + UI.
export default function ModulePage({ item }) {
  return <div>
    <PageHeading eyebrow="ĐANG XÂY DỰNG" title={item.label} subtitle={item.description} />
    <div className="content-grid">
      <Panel title="Chức năng cần có" subtitle="Màn hình sẽ được dựng khi API quản trị tương ứng sẵn sàng">
        <ul className="check-list">{item.actions?.map((action) => <li key={action}><Icon name="check" size={14} />{action}</li>)}</ul>
      </Panel>
      <Panel title="Dữ liệu" subtitle={`Quyền yêu cầu: ${item.permission ?? "—"}`}>
        <TableTags tables={item.tables ?? []} />
      </Panel>
    </div>
  </div>;
}
