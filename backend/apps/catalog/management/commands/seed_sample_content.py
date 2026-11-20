"""Sample content so a fresh install is not empty.

    python manage.py seed_sample_content            # add / refresh the samples
    python manage.py seed_sample_content --once     # only if samples were never added (used on deploy)

Every sample is an ordinary row: the admin can edit, archive or delete it. With
--once a deleted sample never comes back on the next deploy (the sample author
"mate-sample" marks that samples were added).
"""

from datetime import timedelta

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from apps.catalog.models import Author, Category, Content, Series, Topic

# slug: (English name, accent colour, icon)
CATEGORY_STYLE = {
    "kesha-la-usiku": ("Kesha la Usiku", "#F5B544", "cross"),
    "asubuhi-ya-tumaini": ("Morning of Hope", "#FFC98A", "sunrise"),
    "weary-souls": ("Weary Souls", "#E7B7FF", "heart"),
    "marriage-family": ("Marriage & Family", "#8FE3C9", "family"),
    "bible-study": ("Bible Study", "#7CC4FF", "book"),
    "unabii": ("Prophecy", "#FFB0B8", "eye"),
    "sermons": ("Sermons", "#9CCBFF", "mic"),
    "leadership": ("Leadership", "#C7D2FE", "people"),
    "prayer": ("Prayer", "#FDE68A", "hands"),
    "books": ("Books", "#E5E08A", "book"),
    "courses": ("Courses", "#A7F3D0", "school"),
}

# Material icon names the first migration used; replaced by the app's own art keys.
FIRST_SEED_ICONS = {"nights_stay", "wb_sunny", "favorite", "family_restroom", "menu_book", "visibility",
                    "record_voice_over", "groups", "volunteer_activism", "auto_stories", "school"}

AUTHORS = {
    "mate": ("Mate Generous", "Mchungaji", "Mwandishi wa Kesha la Usiku na mhubiri wa Injili."),
    "rehema": ("Rehema Mushi", "Mshauri wa familia", "Huandika kuhusu ndoa, malezi na ibada ya familia."),
}

SERIES = [
    # slug, title, category, author, access, description
    ("zaburi-za-usiku", "Zaburi za Usiku", "kesha-la-usiku", "mate", "free",
     "Zaburi zilizoandikwa gizani, kwa wanaokesha na Mungu."),
    ("kuanza-upya", "Kuanza Upya", "weary-souls", "mate", "free",
     "Kwa waliovunjika moyo: kukataliwa, kushindwa, na neema ya kuanza tena."),
    ("ndoa-imara", "Ndoa Imara", "marriage-family", "rehema", "subscriber",
     "Mawasiliano, migogoro na upendo unaodumu katika ndoa ya Kikristo."),
    ("danieli", "Kitabu cha Danieli", "unabii", "mate", "free",
     "Unabii wa Danieli sura kwa sura: falme, sanamu, na Ufalme usio na mwisho."),
]

TOPICS = ["Tumaini", "Msamaha", "Kusubiri", "Maombi", "Ndoa", "Unabii", "Imani", "Upweke"]


def p(*paras):
    return "".join(f"<p>{x}</p>" for x in paras)


# Each: slug, title, category, series, order, days_ago, access, featured, ref, verse, summary, body, application, prayer, topics
CONTENT = [
    ("kilio-hudumu-usiku-mmoja", "Kilio Hudumu Usiku Mmoja", "kesha-la-usiku", "zaburi-za-usiku", 3, 0, "free", True,
     "Zaburi 30:5", "Kilio huweza kuja kukaa usiku, lakini asubuhi huwa furaha.",
     "Usiku una mwisho. Mungu hakuahidi kwamba hatutalia, aliahidi kwamba kilio hakitakuwa na neno la mwisho.",
     p("Kuna usiku ambao unaonekana hautaisha. Simu haiiti, jibu halifiki, na moyo unachoka kusubiri. Daudi aliandika zaburi hii baada ya kupitia usiku kama huo, si kwa sababu hakuwahi kulia, bali kwa sababu aliona asubuhi ikifika.")
     + "<h2>Usiku una mwisho</h2>"
     + p("Mungu hakuahidi kwamba hatutalia. Aliahidi kwamba kilio hakitakuwa na neno la mwisho. Kilio ni mgeni wa usiku; hakipewi chumba cha kudumu.")
     + "<blockquote>Machozi yako yanajulikana kwa jina na Yule asiyesinzia.</blockquote>"
     + p("Msalaba wenyewe ulikuwa usiku mrefu zaidi wa historia. Lakini Jumapili asubuhi kaburi lilikuwa tupu. Kama Mungu aliweza kugeuza usiku ule kuwa asubuhi, anaweza kugeuza wako pia."),
     "Kabla ya kulala usiku huu, andika jambo moja linalokuliza. Liweke mbele za Mungu kwa jina lake, kisha andika chini yake: <em>Asubuhi inakuja.</em>",
     "Bwana, Wewe unayejua kila chozi, nakukabidhi usiku wangu. Nipe amani ya kulala nikijua kwamba asubuhi iko mikononi mwako. Kwa jina la Yesu, Amina.",
     ["Tumaini", "Kusubiri"]),
    ("mungu-wa-saa-nne", "Mungu wa Saa Nne", "kesha-la-usiku", "zaburi-za-usiku", 2, 1, "free", False,
     "Matendo 16:25", "Lakini usiku wa manane Paulo na Sila walikuwa wakiomba na kumwimbia Mungu nyimbo za kusifu.",
     "Gerezani, wakiwa wamefungwa, Paulo na Sila waliimba. Sifa usiku wa manane hufungua milango.",
     p("Walikuwa wamechapwa, wamefungwa miguu, na wamewekwa ndani kabisa ya gereza. Hakuna aliyetarajia wimbo kutoka mahali kama pale. Lakini usiku wa manane, sauti ya sifa ilisikika.")
     + "<h2>Sifa kabla ya jibu</h2>"
     + p("Hawakusifu kwa sababu milango ilikuwa imefunguka; milango ilifunguka walipokuwa wakisifu. Imani haisubiri mazingira yabadilike ndipo iimbe."),
     "Usiku huu, imba au soma kwa sauti wimbo mmoja wa sifa kabla ya kuomba ombi lako.",
     "Mungu wa usiku wa manane, nifundishe kukusifu kabla sijaona jibu. Fungua minyororo ninayoiona na ile nisiyoiona. Amina.",
     ["Maombi", "Imani"]),
    ("nuru-gizani", "Nuru Gizani", "kesha-la-usiku", "zaburi-za-usiku", 1, 2, "subscriber", False,
     "Yohana 1:5", "Nayo nuru yang'aa gizani, wala giza halikuiweza.",
     "Giza linaweza kuwa kubwa, lakini halijawahi kuishinda nuru ya Kristo.",
     p("Washa kibiriti kimoja katika chumba chenye giza totoro, na giza lote litalazimika kurudi nyuma. Giza halina nguvu ya kuzima nuru; linaweza tu kuwepo pale nuru haipo.")
     + "<h2>Nuru isiyozimika</h2>"
     + p("Yohana anatuambia kwamba nuru ya Kristo iling'aa gizani na giza halikuiweza. Neno hilo linamaanisha pia kwamba giza halikuielewa wala kuishinda."),
     "Taja eneo moja la maisha yako lenye giza. Mwalike Yesu, Nuru ya ulimwengu, aingie hapo leo.",
     "Yesu, Nuru ya ulimwengu, angaza kila kona ya moyo wangu. Giza lolote ndani yangu likimbie mbele zako. Amina.",
     ["Tumaini", "Imani"]),
    ("usiogope-ni-mimi", "Usiogope, Ni Mimi", "kesha-la-usiku", None, 0, 3, "free", False,
     "Mathayo 14:27", "Jipeni moyo; ni mimi; msiogope.",
     "Katikati ya dhoruba, Yesu alikuja akitembea juu ya maji. Sauti yake ni kubwa kuliko upepo.",
     p("Ilikuwa zamu ya nne ya usiku, saa za giza zaidi, wanafunzi walipokuwa wakipigana na mawimbi. Hapo ndipo Yesu alipokuja kwao, akitembea juu ya yale yale maji yaliyowatisha.")
     + p("Mara nyingi Yesu huja kupitia jambo lile lile linalotuogopesha. Hatuhitaji kwanza dhoruba itulie ili tumwone."),
     "Unapoogopa usiku huu, rudia kwa sauti maneno haya matatu: <em>Ni Yeye. Siogopi.</em>",
     "Bwana Yesu, unipe kusikia sauti yako kuliko sauti ya dhoruba. Nipe ujasiri wa kutoka kwenye mashua nikikutazama Wewe. Amina.",
     ["Imani"]),
    ("mlinzi-asiyesinzia", "Mlinzi Asiyesinzia", "kesha-la-usiku", None, 0, 4, "subscriber", False,
     "Zaburi 121:4", "Hakika yeye aliye mlinzi wa Israeli hatasinzia wala hatalala usingizi.",
     "Unaweza kulala kwa amani kwa sababu Yeye anayekulinda halali kamwe.",
     p("Mlinzi wa usiku hupambana na usingizi saa zote za zamu yake. Lakini Mlinzi wetu hana zamu inayoisha wala macho yanayochoka.")
     + p("Kesho yako, watoto wako, kazi yako na afya yako viko chini ya macho yasiyosinzia. Unaweza kupumzika."),
     "Kabla ya kulala, mkabidhi Mungu kwa majina watu watatu unaowapenda.",
     "Baba, Wewe usiyesinzia, nakuachia ulinzi wa nyumba yangu na wapendwa wangu usiku huu. Nalala kwa amani. Amina.",
     ["Tumaini", "Maombi"]),
    ("rehema-mpya-kila-asubuhi", "Rehema Mpya Kila Asubuhi", "asubuhi-ya-tumaini", None, 0, 0, "free", True,
     "Maombolezo 3:22-23", "Ni kwa rehema za BWANA kwamba hatukuangamia, kwa sababu rehema zake hazikomi. Ni mpya kila siku asubuhi.",
     "Leo ni ukurasa mpya. Rehema za jana hazikuisha, na za leo tayari zimefika.",
     p("Yeremia aliandika maneno haya akiwa katikati ya magofu ya Yerusalemu. Hakuona chochote kizuri karibu naye, lakini aliona kitu ndani ya tabia ya Mungu: rehema zisizokoma.")
     + p("Kila asubuhi ni ushahidi kwamba Mungu bado hajamaliza nawe."),
     "Kabla ya kushika simu leo, mshukuru Mungu kwa mambo matatu mapya uliyoyaona asubuhi hii.",
     "Bwana, asante kwa asubuhi hii mpya. Nipe macho ya kuona rehema zako katika kila saa ya leo. Amina.",
     ["Tumaini"]),
    ("asubuhi-bila-kinyongo", "Asubuhi Bila Kinyongo", "asubuhi-ya-tumaini", None, 0, 1, "free", False,
     "Waefeso 4:32", "Tena iweni wafadhili ninyi kwa ninyi, wenye huruma, mkasameheane kama na Mungu katika Kristo alivyowasamehe ninyi.",
     "Usibebe kinyongo cha jana ndani ya siku ya leo. Msamaha ni zawadi unayojipa mwenyewe pia.",
     p("Kinyongo ni kama kubeba jiwe mfukoni siku nzima: hakimdhuru aliyekukosea, kinakuchosha wewe."),
     "Mtumie ujumbe mfupi wa amani mtu mmoja ambaye mlikwaruzana hivi karibuni.",
     "Mungu, kama ulivyonisamehe, nipe neema ya kusamehe leo. Amina.",
     ["Msamaha"]),
    ("ulipokataliwa", "Ulipokataliwa", "weary-souls", "kuanza-upya", 1, 2, "free", True,
     "Zaburi 27:10", "Baba yangu na mama yangu wameniacha, bali BWANA atanikaribisha kwake.",
     "Kukataliwa na watu hakuna mamlaka ya kufuta kukubaliwa na Mungu.",
     p("Kukataliwa kunauma kwa sababu kunagusa swali la ndani kabisa: Je, mimi nina thamani? Daudi alijua maumivu hayo, lakini alijua pia jibu la Mungu.")
     + "<blockquote>Mlango mmoja ukifungwa, mikono ya Baba bado iko wazi.</blockquote>"
     + p("Yesu mwenyewe alikataliwa na wale aliokuja kuwaokoa. Anajua unachopitia, na anakukaribisha."),
     "Andika sentensi hii mahali utakapoiona kila siku: <em>Nimekubaliwa na Mungu.</em>",
     "Baba, maneno ya waliokataa yasizidi sauti yako inayosema mimi ni mwanao. Ponya jeraha hili. Amina.",
     ["Upweke", "Tumaini"]),
    ("ndoto-zilizovunjika", "Ndoto Zilizovunjika", "weary-souls", "kuanza-upya", 2, 5, "subscriber", False,
     "Yoeli 2:25", "Nami nitawarudishieni miaka ile iliyoliwa na nzige.",
     "Mungu ni mtaalamu wa kurejesha kile tulichodhani kimepotea milele.",
     p("Nzige hawaachi kitu. Lakini Mungu aliahidi kurudisha si mavuno tu, bali miaka. Hakuna muda uliopotea ambao Mungu hawezi kuukomboa."),
     "Taja ndoto moja iliyovunjika. Mwambie Mungu aitazame upya pamoja nawe.",
     "Bwana wa urejesho, nakupa vipande vya ndoto zangu. Fanya kitu kipya. Amina.",
     ["Tumaini", "Kusubiri"]),
    ("kusamehe-kusiko-na-masharti", "Kusamehe Kusiko na Masharti", "weary-souls", None, 0, 6, "free", False,
     "Wakolosai 3:13", "Mkichukuliana, na kusameheana, mtu akiwa na sababu ya kumlaumu mwenzake; kama Bwana alivyowasamehe ninyi.",
     "Msamaha haumaanishi kwamba kilichotokea hakikuumiza; unamaanisha kwamba hakitakutawala tena.",
     p("Kusamehe si kusahau, wala si kusema kosa halikuwa kosa. Ni kumkabidhi Mungu deni ambalo wewe huwezi kulilipa wala kulidai tena."),
     "Ombea baraka mtu mmoja aliyekuumiza, hata kama moyo bado unasita.",
     "Yesu, uliyesamehe msalabani, nisaidie kuachilia. Amina.",
     ["Msamaha"]),
    ("mawasiliano-ya-moyo", "Mawasiliano ya Moyo", "marriage-family", "ndoa-imara", 1, 3, "subscriber", True,
     "Yakobo 1:19", "Kila mtu na awe mwepesi wa kusikia, si mwepesi wa kusema, wala si mwepesi wa hasira.",
     "Ndoa nyingi haziharibiwi na tatizo moja kubwa, bali na mazungumzo mengi madogo yasiyosikilizwa.",
     p("Kusikiliza ni zaidi ya kunyamaza ili usubiri zamu yako ya kujibu. Ni kujaribu kuelewa moyo wa mwenzako kabla ya kumwelewesha wako.")
     + "<h2>Zoezi la dakika kumi</h2>"
     + p("Kila mmoja aseme kwa dakika tano bila kukatizwa, kisha mwingine arudie kwa maneno yake alichosikia."),
     "Usiku huu, mwulize mwenzi wako: <em>Ni jambo gani moja ningefanya wiki hii likufanye ujisikie unapendwa?</em>",
     "Mungu wa upendo, tufundishe kusikilizana kama Wewe unavyotusikiliza. Amina.",
     ["Ndoa"]),
    ("migogoro-yenye-afya", "Migogoro Yenye Afya", "marriage-family", "ndoa-imara", 2, 7, "subscriber", False,
     "Waefeso 4:26", "Mwe na hasira, ila msitende dhambi; jua lisichwe na uchungu wenu bado mnao.",
     "Migogoro si adui wa ndoa; jinsi tunavyoishughulikia ndiyo huamua mwisho wake.",
     p("Wanandoa wenye afya nao hugombana. Tofauti ni kwamba wanapigana dhidi ya tatizo, si dhidi ya kila mmoja."),
     "Kubalianeni kanuni moja ya kugombana kwa heshima, mfano: hakuna kupaza sauti.",
     "Bwana, tupe unyenyekevu wa kuomba msamaha kwanza. Amina.",
     ["Ndoa"]),
    ("danieli-2-sanamu-na-jiwe", "Danieli 2: Sanamu na Jiwe", "unabii", "danieli", 2, 4, "free", True,
     "Danieli 2:44", "Na katika siku za wafalme hao Mungu wa mbinguni atasimamisha ufalme ambao hautaangamizwa kamwe.",
     "Falme za dunia zinapita moja baada ya nyingine, lakini Ufalme wa Mungu utasimama milele.",
     p("Nebukadreza aliota sanamu kubwa: kichwa cha dhahabu, kifua cha fedha, tumbo la shaba, miguu ya chuma na udongo. Danieli alieleza kwamba hizi ni falme zinazofuatana katika historia.")
     + "<h2>Jiwe lisilochongwa kwa mikono</h2>"
     + p("Mwishoni jiwe lilipiga sanamu na kuwa mlima mkubwa uliojaa dunia yote. Huu ni Ufalme wa Kristo utakaokuja, usio na mwisho."),
     "Soma Danieli 2 yote wiki hii. Andika falme nne na jinsi historia ilivyotimiza unabii huu.",
     "Mungu wa historia, asante kwamba wakati ujao uko mikononi mwako. Niandae kwa Ufalme wako. Amina.",
     ["Unabii"]),
    ("danieli-1-msimamo", "Danieli 1: Msimamo Katika Babeli", "unabii", "danieli", 1, 8, "free", False,
     "Danieli 1:8", "Lakini Danieli aliazimia moyoni mwake kwamba hatajitia unajisi kwa chakula cha mfalme.",
     "Kabla ya maono makubwa, Danieli alijifunza uaminifu katika mambo madogo.",
     p("Babeli ilitaka kubadilisha jina lake, lugha yake na chakula chake. Danieli aliamua moyoni mwake kubaki mwaminifu kwa Mungu, kwa heshima na hekima."),
     "Taja jambo moja dogo ambalo utaamua kuwa mwaminifu nalo wiki hii.",
     "Bwana, nipe moyo wa Danieli katikati ya Babeli ya leo. Amina.",
     ["Unabii", "Imani"]),
    ("jumbe-za-malaika-watatu", "Jumbe za Malaika Watatu", "unabii", None, 0, 9, "premium", False,
     "Ufunuo 14:6-7", "Kisha nikaona malaika mwingine akiruka katikati ya mbingu, mwenye Injili ya milele.",
     "Ujumbe wa mwisho wa rehema kwa dunia: mcheni Mungu, mpeni utukufu, msujudieni Muumba.",
     p("Ufunuo 14 inaeleza malaika watatu wenye ujumbe kwa kila taifa, kabila, lugha na jamaa. Huu ni mwaliko wa mwisho kabla ya kuja kwa Yesu."),
     "Jifunze Ufunuo 14:6-12 kwa kina na mwombe Mungu akuonyeshe nafasi yako katika ujumbe huu.",
     "Bwana, nifanye mjumbe mwaminifu wa Injili ya milele. Amina.",
     ["Unabii"]),
    ("msamaha-unaoponya", "Msamaha Unaoponya (Hubiri)", "sermons", None, 0, 5, "premium", False,
     "Mathayo 18:21-22", "Sikuambii hata mara saba, bali hata saba mara sabini.",
     "Muundo kamili wa hubiri: utangulizi, historia, tafsiri, vielelezo, matumizi na wito.",
     "<h2>Utangulizi</h2>" + p("Petro alidhani saba ni ukarimu mkubwa. Yesu alijibu kwa hesabu isiyo na mwisho.")
     + "<h2>Historia</h2>" + p("Walimu wa kiyahudi walifundisha kusamehe mara tatu. Petro aliongeza mara mbili zaidi na moja ya ziada.")
     + "<h2>Kielelezo</h2>" + p("Mfano wa mtumishi asiye na huruma (Mathayo 18:23-35) unaonyesha deni kubwa tulilosamehewa.")
     + "<h2>Wito</h2>" + p("Waalike wasikilizaji kumwachilia mtu mmoja kwa jina, mbele za Mungu, leo."),
     "Mhubiri: tumia dakika tano za mwisho kwa maombi ya kimya ya kuachilia.",
     "Baba, tufundishe kusamehe kama tulivyosamehewa. Amina.",
     ["Msamaha"]),
]


class Command(BaseCommand):
    help = "Add sample categories styling, authors, series and devotionals."

    def add_arguments(self, parser):
        parser.add_argument("--once", action="store_true", help="Do nothing if samples were added before.")

    @transaction.atomic
    def handle(self, *args, **opts):
        if opts["once"] and Author.objects.filter(slug="mate-sample").exists():
            self.stdout.write("Samples were added before; skipped.")
            return

        for slug, (name_en, color, icon) in CATEGORY_STYLE.items():
            cat = Category.objects.filter(slug=slug).first()
            if cat is None:
                continue
            cat.name_en = cat.name_en or name_en
            cat.accent_color = cat.accent_color or color
            if not cat.icon or cat.icon in FIRST_SEED_ICONS:
                cat.icon = icon
            cat.save()

        authors = {
            key: Author.objects.get_or_create(slug=f"{key}-sample", defaults={"name": n, "title": t, "bio": b})[0]
            for key, (n, t, b) in AUTHORS.items()
        }
        topics = {name: Topic.objects.get_or_create(name=name)[0] for name in TOPICS}
        cats = {c.slug: c for c in Category.objects.all()}
        series = {}
        for order, (slug, title, cat, author, access, desc) in enumerate(SERIES):
            if cat not in cats:
                continue
            series[slug], _ = Series.objects.update_or_create(
                slug=slug,
                defaults={"title": title, "category": cats[cat], "author": authors[author],
                          "access_level": access, "description": desc, "order": order},
            )

        now = timezone.now().replace(hour=18, minute=0, second=0, microsecond=0)
        if now > timezone.now():
            now -= timedelta(days=1)
        created = 0
        for (slug, title, cat, ser, order, days_ago, access, featured, ref, verse, summary,
             body, application, prayer, topic_names) in CONTENT:
            if cat not in cats:
                continue
            item, was_created = Content.objects.update_or_create(
                slug=slug,
                defaults={
                    "title": title, "category": cats[cat], "series": series.get(ser), "order_in_series": order,
                    "author": authors["rehema" if cat == "marriage-family" else "mate"],
                    "scripture_reference": ref, "scripture_text": verse, "summary": summary,
                    "body": body, "application": application, "prayer": prayer,
                    "access_level": access, "is_featured": featured, "status": "published",
                    "share_excerpt": summary,
                    "publish_at": now - timedelta(days=days_ago, minutes=order),
                    "kind": "sermon" if cat == "sermons" else "devotional",
                },
            )
            item.topics.set([topics[t] for t in topic_names])
            created += was_created
        self.stdout.write(self.style.SUCCESS(f"Samples ready: {len(CONTENT)} items ({created} new)."))
