package wgm

import grails.testing.mixin.integration.Integration
import grails.gorm.transactions.Rollback
import spock.lang.Specification
import org.hibernate.SessionFactory

@Integration
@Rollback
class VendedoraServiceSpec extends Specification {

    VendedoraService vendedoraService
    SessionFactory sessionFactory

    private Long setupData() {
        // TODO: Populate valid domain instances and return a valid ID
        //new Vendedora(...).save(flush: true, failOnError: true)
        //new Vendedora(...).save(flush: true, failOnError: true)
        //Vendedora vendedora = new Vendedora(...).save(flush: true, failOnError: true)
        //new Vendedora(...).save(flush: true, failOnError: true)
        //new Vendedora(...).save(flush: true, failOnError: true)
        assert false, "TODO: Provide a setupData() implementation for this generated test suite"
        //vendedora.id
    }

    void "test get"() {
        setupData()

        expect:
        vendedoraService.get(1) != null
    }

    void "test list"() {
        setupData()

        when:
        List<Vendedora> vendedoraList = vendedoraService.list(max: 2, offset: 2)

        then:
        vendedoraList.size() == 2
        assert false, "TODO: Verify the correct instances are returned"
    }

    void "test count"() {
        setupData()

        expect:
        vendedoraService.count() == 5
    }

    void "test delete"() {
        Long vendedoraId = setupData()

        expect:
        vendedoraService.count() == 5

        when:
        vendedoraService.delete(vendedoraId)
        sessionFactory.currentSession.flush()

        then:
        vendedoraService.count() == 4
    }

    void "test save"() {
        when:
        assert false, "TODO: Provide a valid instance to save"
        Vendedora vendedora = new Vendedora()
        vendedoraService.save(vendedora)

        then:
        vendedora.id != null
    }
}
