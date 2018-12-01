package wgm

import grails.testing.mixin.integration.Integration
import grails.gorm.transactions.Rollback
import spock.lang.Specification
import org.hibernate.SessionFactory

@Integration
@Rollback
class ImagemServiceSpec extends Specification {

    ImagemService imagemService
    SessionFactory sessionFactory

    private Long setupData() {
        // TODO: Populate valid domain instances and return a valid ID
        //new Imagem(...).save(flush: true, failOnError: true)
        //new Imagem(...).save(flush: true, failOnError: true)
        //Imagem imagem = new Imagem(...).save(flush: true, failOnError: true)
        //new Imagem(...).save(flush: true, failOnError: true)
        //new Imagem(...).save(flush: true, failOnError: true)
        assert false, "TODO: Provide a setupData() implementation for this generated test suite"
        //imagem.id
    }

    void "test get"() {
        setupData()

        expect:
        imagemService.get(1) != null
    }

    void "test list"() {
        setupData()

        when:
        List<Imagem> imagemList = imagemService.list(max: 2, offset: 2)

        then:
        imagemList.size() == 2
        assert false, "TODO: Verify the correct instances are returned"
    }

    void "test count"() {
        setupData()

        expect:
        imagemService.count() == 5
    }

    void "test delete"() {
        Long imagemId = setupData()

        expect:
        imagemService.count() == 5

        when:
        imagemService.delete(imagemId)
        sessionFactory.currentSession.flush()

        then:
        imagemService.count() == 4
    }

    void "test save"() {
        when:
        assert false, "TODO: Provide a valid instance to save"
        Imagem imagem = new Imagem()
        imagemService.save(imagem)

        then:
        imagem.id != null
    }
}
