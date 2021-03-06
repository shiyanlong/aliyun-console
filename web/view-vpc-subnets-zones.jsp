<%@ page contentType="text/html;charset=UTF-8"%>
<html>
<head>
    <title>VPC Connections View</title>

    <!--jquery libraries-->
    <script class="js_jquery" src="js/external/jquery/jquery-3.3.1.min.js"></script>
    <%--<script class="js_jquery" src="js/external/jquery/jquery-3.3.1.js"></script>--%>
    <script class="js_jquery_cookie" src="js/external/jquery/jquery.cookie-1.4.1.min.js"></script>
    <script class="js_jquery_ui" src="js/external/jquery/jquery-ui-1.12.1/jquery-ui.min.js"></script>

    <!--tippy libraries-->
    <script class="js_tippy" src="js/external/tippy.all.min.js"></script>

    <!--d3 libraries-->
    <script class="js_d3" src="js/external/d3js/d3.js"></script>

    <%--datatables libraries--%>
    <link rel="stylesheet" href="js/external/DataTables/datatables.min.css">
    <script src="js/external/DataTables/datatables.min.js"></script>

    <!--custom theme styles-->
    <link class="css_custom css_fonts" rel="stylesheet" href="css/fonts.css">
    <link class="css_custom css_table_view" rel="stylesheet" href="css/table_view.css">
    <link class="css_custom css_theme_control" rel="stylesheet" href="css/theme_control.css">
    <link class="css_custom css_tippy_custom" rel="stylesheet" href="css/tippy_custom.css">

    <!--custom javascripts-->
    <script class="js_custom js_btn_callbacks" src="js/btn_callbacks.js"></script>
    <script class="js_custom js_d3_chord_gen" src="js/d3_chord_gen.js"></script>
    <script class="js_custom js_helpers" src="js/helpers.js"></script>
    <script class="js_custom js_helpers_web" src="js/helpers_web.js"></script>

    <%--import templates--%>
    <link rel="import" id="template_ecs_panel" href="template_ecs_panel.html">
    <link rel="import" id="template_inst_box" href="template_inst_box.html">

    <style>
        td, th {
            border-radius: 5px;
            vertical-align: top;
            border: solid transparent;
        }

        th {
            vertical-align: middle;
        }

        td .cellBanner {
            display: block;
            margin: 0.2em 0.3em;
            text-align: center;
            font-size: 9pt;
            color: #4d4d4d;
        }

        table {
            border-spacing: 5px !important;
        }

        .subnet {
            border-radius: 5px;
            background-color: #00000017;
            margin: 3px;
            padding: 2px;
        }

        .tippy-tooltip {
            background-color: unset;
        }

        .tippy-popper {
            width: fit-content;
        }

        .colgrp-odd {
            background-color: #ebf1ff;
        }

        .colgrp-even {
            background-color: #fff2ef;
        }
    </style>

    <script>
        $(document).ready(function () {
            //add back button
            addHomeButton();
            //update select from cookies
            loadCookies(['target_region']);
            //initialize dataTable
            initDataTables('.dataTable', 0);
            //set column group based on first row's rowspan settings
            let /**HTMLElement*/firstRow = $('.dataTable thead tr:nth-child(1)')[0];//vpc row
            let /**HTMLElement*/secondRow = $('.dataTable thead tr:nth-child(2)')[0];//zone row
            if (firstRow == null || secondRow == null) return;
            let lastColClass = false;
            let colClasses = [];
            [...secondRow.children].forEach((cell, cellIdx) => {
                if (cellIdx === 0)
                    colClasses.push(null);
                else {
                    let colHeaderCell = firstRow.children[cellIdx];
                    if (!colHeaderCell.hidden) lastColClass = !lastColClass;
                    colClasses.push(lastColClass);
                }
            });
            colClasses.forEach((b, i) => {
                if (b != null) $('.dataTable tr > :nth-child('+(i+1)+')').addClass(b ? 'colgrp-odd' : 'colgrp-even');
            });
            //load filters
            let filters = $.cookie('filters');
            if (filters) unserializeFilters(filters);
        });
    </script>
</head>
<body>
<h3>Select Region</h3>
<form id="options_form" method="post">
    <select id="target_region" name="target_region">
        <option disabled selected value>-- Select Region --</option>
        <option value="cn-beijing">China North 2 (Beijing)</option>
        <option value="cn-hongkong">Hong Kong</option>
    </select>
    <input type="checkbox" name="refresh_cache" id="refresh_cache">Ignore Cache (Slow)
    <input type="submit" id="btn_submit" value="  Go  " onclick="btn_submit_onclick()"/>
</form>
<form onsubmit="try { applyFilters(); } finally { return false; }">
    <span style="margin-right: 1em">Filters</span><span id="span_counter" style="margin-right: 1em"></span>
    <input type="button" value=" + " onclick="addFilter()">
    <input type="submit" value="  Apply  ">
    <input id="btn_filter_bypass" type="button" value="  Bypass  " disabled onclick="clearFilters(false)">
    <input id="btn_filter_revert" type="button" value="  Revert  " onclick="revertFilterResult()">
    <div id="div_filters"></div>
</form>
<datalist>
    <
</datalist>
<script>
    /**@type {Map<string, {datalistMap:Map<string, string>}>}*/
    let allFields = null;
    let /**HTMLSelectElement*/sel_operator = null;
    function addFilter() {
        let div_filters = document.getElementById('div_filters');

        let div_filter = document.createElement('div');
        //datalist for all fields
        if (allFields == null) {
            allFields = generateAllFields([...allEcs.values(), ...allRds.values()]);
            let dl = createElement('datalist', {'id':'dl_fields'});
            for (let item of [...allFields.keys()].sort()) {
                dl.createElement('option', {'value':item});
            }
            document.body.appendChild(dl);
        }

        //input that points to fields datalist
        let input_fields = createElement('input', {'type':'text', 'list':'dl_fields'});
        input_fields.onchange = propNameChanged;
        div_filter.appendChild(input_fields);

        //add fake input_filterVal as a placeholder
        div_filter.createElement('input', {'type':'text', 'disabled':''});

        //select (logical operator)
        if (sel_operator == null) {
            sel_operator = document.createElement('select');
            sel_operator.add(createElement('option', { 'value': 'and' }, { 'textContent': 'AND' }));
            sel_operator.add(createElement('option', { 'value': 'or' }, { 'textContent': 'OR' }));
        }
        div_filter.appendChild(sel_operator.cloneNode(true));
        //remove button
        let btn_remove = createElement('input', {'type':'button', 'value':' - '});
        btn_remove.onclick = function () { $(this.parentElement).remove(); };
        div_filter.appendChild(btn_remove);

        div_filters.appendChild(div_filter);
        return div_filter;
    }

    function propNameChanged() {
        let propName = this.value;
        let fieldInfo = allFields.get(propName);
        if (fieldInfo === undefined) return;

        //remove old input together with datalist (jquery event)
        $(this.nextElementSibling).remove();

        //generate datalist and input
        let dlId = 'dl_filter_' + propName;
        if (document.getElementById(dlId) == null) {
            let dl = document.createElement('datalist'); dl.id = dlId;
            let ary = [...fieldInfo.datalistMap.entries()].sort(_sortAryBy1Then0);
            for (let item of ary) {
                dl.createElement('option', {'value':item[0], 'label':item[1]});
            }
            document.body.appendChild(dl);
        }
        let input_filterVal = createElement('input', { 'type': 'text', 'list': dlId });
        $(input_filterVal).on('remove', function () { if (this.list) this.list.remove(); });//remove associated datalist with the input
        this.insertAdjacentElement('afterend', input_filterVal);
    }

    function clearFilters(/**boolean*/removeCookie) {
        //show all inst-box
        let all = $('.inst-box'); all.show();
        let counter = document.getElementById('span_counter');
        counter.textContent = '(' + all.length + ' shown, ' + '0 hidden)';
        //update filters cookie
        if (removeCookie) $.removeCookie('filters');
        //disable bypass button
        document.getElementById('btn_filter_bypass').setAttribute('disabled', '');
    }

    function revertFilterResult() {
        let all = $('.inst-box'); all.toggle();
        let counter = document.getElementById('span_counter');
        counter.textContent = '(' + all.filter(':visible').length + ' shown, ' + all.filter(':hidden').length + ' hidden)';
    }

    function applyFilters() {
        let div_filters = document.getElementById('div_filters');
        let counter = document.getElementById('span_counter');
        if (div_filters.children.length === 0) { clearFilters(true); return; }

        let result = new Map([...allEcs, ...allRds]);
        //reset previous filter result
        result.forEach(i => delete i._show);
        //apply each filter
        for (let div_filter of div_filters.children) {
            let propName = div_filter.children[0].value;
            let filterVal = div_filter.children[1].value;
            let operator = div_filter.children[2].value;
            updateFilterResult(result, propName, filterVal, operator);
        }

        let showIds = [], hideIds = [];
        for (let pair of result.entries()) {
            if (pair[1]._show) showIds.push(pair[0]);
            else hideIds.push(pair[0]);
        }
        $("[data-instId='" + showIds.join("'],[data-instId='") + "']").show();
        $("[data-instId='" + hideIds.join("'],[data-instId='") + "']").hide();

        counter.textContent = '(' + showIds.length + ' shown, ' + hideIds.length + ' hidden)';

        //save filter to cookie
        $.cookie('filters', serializeFilters());
        //enable bypass
        document.getElementById('btn_filter_bypass').removeAttribute('disabled');
    }

    /**
     * @param {Map} map
     * @param {string} propName
     * @param {string} filterVal
     * @param {'and' | 'or'} operator
     */
    function updateFilterResult(map, propName, filterVal, operator) {
        filterVal = filterVal.toLowerCase();
        for (let pair of map.entries()) {
            let inst = pair[1];
            if (inst._show === false && operator === 'and') continue;
            let realVal = inst[propName];
            let show = false;
            if (realVal !== undefined && realVal != null)
                show = _findValue(realVal, filterVal);
            if (inst._show === undefined) inst._show = show;
            else {
                if (operator === 'and' && inst._show === true) inst._show = show;
                else if (operator === 'or' && inst._show === false) inst._show = show;
            }
        }
    }

    function _findValue(obj, value) {
        let show = false;
        switch (obj.constructor.name) {
            case 'String':
                if (obj.toLowerCase().includes(value)) show = true;
                break;
            case 'Number':
                if (Number(value) === obj) show = true;
                break;
            case 'Array':
                for (let child of obj) {
                    show = _findValue(child, value);
                    if (show) break;
                }
                break;
            case 'Object':
                for (let child of Object.values(obj)) {
                    show = _findValue(child, value);
                    if (show) break;
                }
                break;
        }
        return show;
    }

    function _sortAryBy1Then0(a, b) {
        if (a[1] > b[1]) return 1;
        if (a[1] < b[1]) return -1;
        if (a[0] > b[0]) return 1;
        if (a[0] < b[0]) return -1;
        return 0;
    }

    /**
     * @param {Array<object>} instAry
     * @return {Map<string, {datalistMap:Map<string, string>}>}
     */
    function generateAllFields(instAry) {
        /**@type {Map<string, {datalistMap:Map<string, string>}>}*/
        let map = new Map();
        for (let inst of instAry) {
            for (let key of Object.keys(inst)) {
                if (!map.has(key)) map.set(key, {'datalistMap':new Map()});
                let fieldInfo = map.get(key);
                let oldMap = fieldInfo.datalistMap;
                switch (key) {
                    case 'tags':
                        for (let tag of inst[key]) {
                            oldMap.set(tag.tagValue, tag.tagKey);
                        }
                        break;
                    case 'vpcAttributes':
                        let vpcAttr = inst[key];
                        let vpc = allVpc.get(vpcAttr.vpcId);
                        let vsw = allVsw.get(vpcAttr.vSwitchId);
                        oldMap.set(vpc.vpcId, 'VPC: ' + vpc.vpcName);
                        oldMap.set(vsw.vSwitchId, 'vSwitch: ' + vsw.vSwitchName + ' ('+ vpc.vpcName +')');
                        break;
                    case 'securityGroupIds':
                        for (let sgId of inst[key]) {
                            let sg = allSG.get(sgId);
                            oldMap.set(sgId, sg.securityGroupName + ' (' + allVpc.get(sg.vpcId).vpcName + ')');
                        }
                        break;
                    case 'networkInterfaces':
                        for (let ni of inst[key]) {
                            oldMap.set(ni.primaryIpAddress, null);
                        }
                        break;
                    default:
                        oldMap.set(inst[key].toString(), null);
                        break;
                }
            }
        }
        return map;
    }


    function serializeFilters() {
        let filterAry = [];
        let div_filters = document.getElementById('div_filters');
        if (div_filters == null) return null;
        for (let div_filter of div_filters.children) {
            let propName = div_filter.children[0].value;
            let filterVal = div_filter.children[1].value;
            let operator = div_filter.children[2].value;
            filterAry.push({ 'propName':propName, 'filterVal':filterVal, 'operator':operator });
        }
        return JSON.stringify(filterAry);
    }

    function unserializeFilters(filterJson) {
        let div_filters = document.getElementById('div_filters');
        if (div_filters == null) return;
        $(div_filters).empty();//cannot use childNode.remove() as it will not trigger jQuery event 'remove'.

        let filterAry = JSON.parse(filterJson);
        for (let filterObj of filterAry) {
            let div_filter = addFilter();
            div_filter.children[0].value = filterObj.propName;
            div_filter.children[0].dispatchEvent(new Event('change'));
            div_filter.children[1].value = filterObj.filterVal;
            div_filter.children[2].value = filterObj.operator;
        }
    }
</script>


<%
    String[] p_target_region = request.getParameterValues("target_region");
    if (p_target_region == null || p_target_region.length == 0) return;
%>

<script>
    'use strict';
    let region = $.cookie('target_region');
    let cache = $.cookie('refresh_cache') !== 'true';//cannot use ! to invert boolean as cookies are stored as strings

    let /**Map<string,VPC>*/ allVpc = getInstances(region, 'Vpc', null, cache, null, 'map');//.sort((a, b) => Date.parse(a.creationTime) - Date.parse(b.creationTime))
    let /**Map<string,vSwitch>*/ allVsw = getInstances(region, 'Vswitch', null, cache, null, 'map');
    let /**Map<string,ECS>*/ allEcs = getInstances(region, 'Ecs', null, cache, null, 'map');
    let /**Map<string,SecGrp>*/ allSG = getInstances(region, 'SecurityGroup', null, cache, null, 'map');
    let /**Array*/ allDisk = getInstances(region, 'Disk', null, cache, null);
    let /**Map<string,RDS>*/ allRds = getInstances(region, 'Rds', null, cache, null, 'map');

    let allEcsDisk = allDisk.reduce((pre, cur) =>
        pre.has(cur.instanceId) ? (pre.get(cur.instanceId).push(cur), pre) : pre.set(cur.instanceId, [cur]), new Map());

    if (allVpc.size + allVsw.size + allEcs.size === 0) throw new Error('Empty collections. Aborting.');

    /**
     * Structure:
     * vpc-xxx ─┬─ cn-beijing-a ─┬─ vsw-xxx: { vSwitch obj }
     *          ├─ cn-beijing-c  ├─ vsw-xxx: { vSwitch obj }
     *          ├─ cn-beijing-e  └─ ...
     *          └─ ...
     */
    let cols = [...allVsw.values()].reduce((pre, cur) => {
        if (pre[cur.vpcId]) {
            if (pre[cur.vpcId][cur.zoneId])
                pre[cur.vpcId][cur.zoneId][cur.vSwitchId] = cur;
            else
                pre[cur.vpcId][cur.zoneId] = { [cur.vSwitchId]: cur };
        }
        else
            pre[cur.vpcId] = { [cur.zoneId]: { [cur.vSwitchId]: cur } };
        return pre;
    }, {});

    /**
     * Structure:
     * {
     *   "vpc-2zefhkx9yqfdgxk3q046d,cn-beijing-a" => [ {vsw obj}, {vsw obj}, ... ],
     *   "vpc-2zefhkx9yqfdgxk3q046d,cn-beijing-c" => [ {vsw obj}, {vsw obj}, ... ],
     *   "vpc-2zejcg6ef7tbekas6f9e5,cn-beijing-a" => [ {vsw obj}, {vsw obj}, ... ],
     *   "vpc-2zejcg6ef7tbekas6f9e5,cn-beijing-e" => [ {vsw obj}, {vsw obj}, ... ],
     *   ...
     * }
     * */
    let colsFlat = Object.entries(cols).reduce((pre, cur) => {
        let vid = cur[0], val = cur[1];
        for (let zid in val) {
            if (!val.hasOwnProperty(zid)) continue;
            pre.set(vid + ',' + zid, { index: pre.size, vpcId: vid, zoneId: zid, vswList: val[zid]});
        }
        return pre;
    }, new Map());

    // let colsData = Object.entries(cols).reduce((pre, cur) => (pre.push(...Object.keys(cur[1]).map(c=>[cur[0], c])), pre), {});

    function getRowKey(vsw) {
        let zoneSuffix = vsw.zoneId.substring(vsw.zoneId.lastIndexOf('-')).toUpperCase();//is something like '-A' or '-C'
        let _i = vsw.vSwitchName.toUpperCase().lastIndexOf(zoneSuffix);
        return _i === -1 ? vsw.vSwitchName : vsw.vSwitchName.substring(0, _i);//remove -A when possible
    }

    /** @type { Map<string,Array> }*/
    let rows = [...allVsw.values()].reduce((pre, cur) => {
        let rowKey = getRowKey(cur);
        let colKey = cur.vpcId + ',' + cur.zoneId;
        let colIdx = colsFlat.get(colKey).index;
        if (!pre.has(rowKey)) pre.set(rowKey, Array(colsFlat.size));
        let row = pre.get(rowKey);
        if (row[colIdx] == null) row[colIdx] = {};
        row[colIdx][cur.vSwitchId] = { vSwitch: cur };
        row[colIdx][cur.vSwitchId].ecsList = [];
        row[colIdx][cur.vSwitchId].rdsList = [];
        return pre;
    }, new Map());

    //fill ecs instances
    for (let ecs of allEcs.values()) {
        let vsw = allVsw.get(ecs.vpcAttributes.vSwitchId);
        let rowKey = getRowKey(vsw);
        let colKey = vsw.vpcId + ',' + vsw.zoneId;
        let colIdx = colsFlat.get(colKey).index;
        rows.get(rowKey)[colIdx][vsw.vSwitchId].ecsList.push(ecs);
    }

    //fill rds instances
    for (let rds of allRds.values()) {
        let vsw = allVsw.get(rds.vSwitchId);
        let rowKey = getRowKey(vsw);
        let colKey = vsw.vpcId + ',' + vsw.zoneId;
        let colIdx = colsFlat.get(colKey).index;
        rows.get(rowKey)[colIdx][vsw.vSwitchId].rdsList.push(rds);
    }

    //header row
    let table = d3.select('body').append('table').attr('class', 'dataTable cell-border hover order-column ');
    let thead = table.append('thead');
    let trh1 = thead.append('tr');
    trh1.selectAll('th').data([...colsFlat.values()]).enter().append('th').text(d => allVpc.get(d.vpcId).vpcName);
    trh1.insert('th', ':first-child');
    let trh2 = thead.append('tr');
    trh2.selectAll('th').data([...colsFlat.values()]).enter().append('th').text(d => d.zoneId);
    trh2.insert('th', ':first-child');

    //body rows
    let tbody = table.append('tbody');
    let bodyRows = tbody.selectAll('tr')
        .data([...rows.entries()], kv => kv[0]).enter()
        .append('tr');

    let instBoxNode = document.querySelector('#template_inst_box').import.querySelector('.inst-box');

    bodyRows.selectAll('td')
        .data(kv => kv[1]).enter()
        .append(cd => {
            let td = document.createElement('td');
            if (cd != null) {
                Object.values(cd).forEach(d => {
                    let vsw = d.vSwitch;
                    let vswdiv = document.createElement('div');
                    vswdiv.className = 'subnet';
                    vswdiv.appendChild(createElement('a', {'class': 'cellBanner'},
                        {
                            'innerText': vsw.cidrBlock + ' | ' + vsw.zoneId.toUpperCase(),
                            'href': 'https://vpcnext.console.aliyun.com/vpc/'+region+'/switches?VSwitchId='+vsw.vSwitchId,
                            'target': '_blank'
                        }));
                    if (d.ecsList.length > 0) {
                        d.ecsList.sort(getCompareFunc('instanceName'));
                        for (let ecs of d.ecsList) {
                            let clone = document.importNode(instBoxNode, true);
                            fillEcsBoxData(ecs, clone);
                            vswdiv.appendChild(clone);
                        }
                    }
                    if (d.rdsList.length > 0) {
                        d.rdsList.sort(getCompareFunc('dBInstanceDescription'));
                        for (let rds of d.rdsList) {
                            let clone = document.importNode(instBoxNode, true);
                            fillRdsBoxData(rds, clone);
                            vswdiv.appendChild(clone);
                        }
                    }
                    td.appendChild(vswdiv);
                });
            }
            return td;
        });

    bodyRows.insert('th', ':first-child').text(kv => kv[0]);//kv[0] is the row key
    let ecsPanelNode = document.querySelector('#template_ecs_panel').import.querySelector('.ecs-panel');

    //inst-box
    tippy('.inst-box', {
        placement: 'right',
        animateFill: false,
        interactive: true,
        trigger: 'click',
        html: function (instDiv) {
            //generate tooltip content
            switch (instDiv.getAttribute('data-InstCat')) {
                case 'ecs': {
                    let ecs = allEcs.get(instDiv.getAttribute('data-InstId'));
                    //fill in ecs data
                    let clone = document.importNode(ecsPanelNode, true);
                    // let clone = ecsPanelNode.cloneNode(true); appears to be the same effect
                    fillEcsPanelData(ecs, allEcsDisk.get(ecs.instanceId), allSG, clone);
                    updateExpand(clone);
                    applyAccordion(clone);
                    return clone;
                }
                case 'rds': {
                    let rds = allRds.get(instDiv.getAttribute('data-InstId'));
                    let clone = document.importNode(ecsPanelNode, true);
                    fillRdsPanelData(rds, clone);
                    return clone;
                }
            }
        },
        popperOptions: {
            modifiers: {
                computeStyle: {
                    gpuAcceleration: false
                }
            }
        },
        onShown(instance) {
            if (instance.reference && instance.reference.getAttribute('data-InstCat') === 'rds') return;

            let /**HTMLElement*/ panelElement = $('.ecs-panel', instance.popper)[0];
            let billing_gb = panelElement.querySelector('#billing-gb');
            if (billing_gb.getAttribute('data-PriceUpdated') === 'true') return;

            let ecsId = instance.reference.getAttribute('data-InstId');
            let ecs = allEcs.get(ecsId);

            getPrice(ecs.regionId, 'Ecs', ecs.instanceId, function (price) {
                for (let priceType in price) {
                    if (!price.hasOwnProperty(priceType)) continue;
                    let price_p =
                        createElement('p').
                        createElement('strong', null, {'innerText': priceType + ': '}).
                        createElement('span', null, {'innerText': price[priceType].tradePrice + ' ' + price[priceType].currency});
                    $(price_p).hide();
                    billing_gb.appendChild(price_p);
                    $(price_p).show(500);
                }
                billing_gb.setAttribute('data-PriceUpdated', 'true');
            });
        }
    });

</script>

</body>
</html>
