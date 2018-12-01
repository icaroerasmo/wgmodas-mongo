package wgm

import grails.testing.mixin.integration.Integration
import grails.gorm.transactions.Rollback
import spock.lang.Specification
import org.hibernate.SessionFactory

@Integration
@Rollback
class FabricaServiceSpec extends Specification {

    FabricaService fabricaService
    SessionFactory sessionFactory

    private Long setupData() {
        // TODO: Populate valid domain instances and return a valid ID
        //new Fabrica(...).save(flush: true, failOnError: true)
        //new Fabrica(...).save(flush: true, failOnError: true)
        //Fabrica fabrica = new Fabrica(...).save(flush: true, failOnError: true)
        //new Fabrica(...).save(flush: true, failOnError: true)
        //new Fabrica(...).save(flush: true, failOnError: true)
        assert false, "TODO: Provide a setupData() implementation for this generated test suite"
        //fabrica.id
    }

    void "test get"() {
        setupData()

        expect:
        fabricaService.get(1) != null
    }

    void "test list"() {
        setupData()

        when:
        List<Fabrica> fabricaList = fabricaService.list(max: 2, offset: 2)

        then:
        fabricaList.size() == 2
        assert false, "TODO: Verify the correct instances are returned"
    }

    void "test count"() {
        setupData()

        expect:
        fabricaService.count() == 5
    }

    void "test delete"() {
        Long fabricaId = setupData()

        expect:
        fabricaService.count() == 5

        when:
        fabricaService.delete(fabricaId)
        sessionFactory.currentSession.flush()

        then:
        fabricaService.count() == 4
    }

    void "test save"() {
        when:
        assert false, "TODO: Provide a valid instance to save"
        Fabrica fabrica = new Fabrica()
        fabricaService.save(fabrica)

        then:
        fabrica.id != null
    }
}
