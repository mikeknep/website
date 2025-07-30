---
title: Metra
---


## Wilmette to Rogers Park

<ul id="wilmette-to-rp"></ul>

## Rogers Park to Wilmette

<ul id="rp-to-wilmette"></ul>

<br>

## Downtown to RP

### Full schedules w/ all stops
<ul>
    <li id="otc-to-rp-weeknight"></li>
    <li id="otc-to-rp-saturday"></li>
    <li id="otc-to-rp-sunday"></li>
</ul>

### Weeknights hourly


| Rogers Park | **x:52** |
| Ravenswood | **x:45** |
| Clybourn | **x:40** |
| Ogilvie | **x:32** |

(Starting at 6:32pm)




<script>

function getWeekdayDaysOffset() {
    const now = new Date();
    const today = now.getDay();

    // It's already a weekday. No offset needed.
    if (today < 6) {
        return 0;
    }
    // It's Saturday! Monday is two days away.
    if (today === 6) {
        return 2;
    }
    // It's Sunday. Tomorrow is Monday.
    if (today === 7) {
        return 1;
    }
}

function getSaturdayDaysOffset() {
    const now = new Date();
    const today = now.getDay();

    // It's Saturday!
    if (today === 6) {
        return 0;
    }
    // It's Sunday. Look ahead to next Saturday.
    if (today === 7) {
        return 6;
    }
    // It's a weekday. Calculate how many days away Saturday is.
    return 6 - today;
}

function getSundayDaysOffset() {
    const now = new Date();
    const today = now.getDay();

    return 7 - today;
}

function get8amOnDay(daysOffset) {
    const nextDate = new Date();
    nextDate.setDate(nextDate.getDate() + daysOffset);
    // Metra doesn't like midnight for some reason; 8am works better to show all trains that day
    nextDate.setHours(8);

    // getTime returns milliseconds
    // Metra expects seconds
    return Math.floor(nextDate.getTime() / 1000);
}

function getTripleTimestampSet() {
    return [
        ["Weekday", get8amOnDay(getWeekdayDaysOffset())],
        ["Saturday", get8amOnDay(getSaturdayDaysOffset())],
        ["Sunday", get8amOnDay(getSundayDaysOffset())]
    ];
}

function makeHref(to, from, time, allStops) {
    return `https://www.metra.com/schedules?line=UP-N&orig=${to}&dest=${from}&time=${time}&allstops=${allStops}`;
}

function makeLink(to, from, time, text, allStops) {
    const a = document.createElement("a");
    a.href = makeHref(to, from, time, allStops);
    a.textContent = text;
    a.target = "_blank";

    return a
}

function addLinkToList(link, listId) {
    const li = document.createElement("li");
    li.appendChild(link)

    const ul = document.getElementById(listId);
    ul.appendChild(li);
}

function addLinkToLi(link, liId) {
    const li = document.getElementById(liId);
    li.appendChild(link);
}


// Populate the Wilmette<-->Rogers Park lists
const timestamps = getTripleTimestampSet();
for (let i in timestamps) {
    let [text, time] = timestamps[i];
    addLinkToList(makeLink("WILMETTE", "ROGERPK", time, text, 0), "wilmette-to-rp");
    addLinkToList(makeLink("ROGERPK", "WILMETTE", time, text, 0), "rp-to-wilmette");
}

// Downtown->Rogers Park
addLinkToLi(makeLink("OTC", "ROGERPK", get8amOnDay(getWeekdayDaysOffset()), "Weekday", 1), "otc-to-rp-weeknight");
addLinkToLi(makeLink("OTC", "ROGERPK", get8amOnDay(getSaturdayDaysOffset()), "Saturday", 1), "otc-to-rp-saturday");
addLinkToLi(makeLink("OTC", "ROGERPK", get8amOnDay(getSundayDaysOffset()), "Sunday", 1), "otc-to-rp-sunday");

</script>
